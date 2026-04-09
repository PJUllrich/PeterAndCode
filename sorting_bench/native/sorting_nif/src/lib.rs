use rustler::{Binary, OwnedBinary, ResourceArc, Atom, Resource};
use std::sync::Mutex;

mod atoms {
    rustler::atoms! {
        ok,
        error,
    }
}

// =============================================================================
// Approach 1: Standard NIF — list protocol (full copy in + full copy out)
//
// The BEAM converts the Elixir list into a Rust Vec<i64> (O(n) copy),
// Rust sorts, then converts back to an Elixir list (O(n) copy).
// This is the REFERENCE for copy-cost measurement.
// =============================================================================
#[rustler::nif(schedule = "DirtyCpu")]
fn sort_list(list: Vec<i64>) -> Vec<i64> {
    let mut v = list;
    v.sort_unstable();
    v
}

// =============================================================================
// Approach 2: Binary NIF — safe copy (refc binary in, new binary out)
//
// Input: refc binary (>64 bytes) is passed by reference — near-zero copy.
// The NIF allocates a new binary, copies the data, sorts in-place, returns it.
// Copy cost: ~1 memcpy (input ref + output alloc).
// =============================================================================
#[rustler::nif(schedule = "DirtyCpu")]
fn sort_binary(binary: Binary) -> OwnedBinary {
    let data = binary.as_slice();
    let num_elements = data.len() / std::mem::size_of::<i64>();

    let mut owned = OwnedBinary::new(data.len()).unwrap();
    owned.as_mut_slice().copy_from_slice(data);

    let slice = unsafe {
        std::slice::from_raw_parts_mut(
            owned.as_mut_slice().as_mut_ptr() as *mut i64,
            num_elements,
        )
    };
    slice.sort_unstable();
    owned
}

// =============================================================================
// Approach 3: Binary NIF — in-place sort (UNSAFE, zero copy)
//
// Input: refc binary passed by reference (zero copy).
// The NIF casts the const pointer to mutable and sorts in-place.
// Output: returns :ok — the caller reads the same binary back.
//
// ⚠️  UNSAFE: mutates a binary the BEAM considers immutable.
//     Only safe if no other process holds a reference to this binary.
//     The benchmark creates a fresh :binary.copy/1 per iteration.
// =============================================================================
#[rustler::nif(schedule = "DirtyCpu")]
fn sort_binary_inplace(binary: Binary) -> Atom {
    let data = binary.as_slice();
    let num_elements = data.len() / std::mem::size_of::<i64>();

    let slice = unsafe {
        std::slice::from_raw_parts_mut(
            data.as_ptr() as *mut i64,
            num_elements,
        )
    };
    slice.sort_unstable();
    atoms::ok()
}

// =============================================================================
// Approach 4: Shared memory via mmap (zero-copy sort, memcpy for I/O)
//
// Uses /dev/shm (tmpfs) so mmap never touches disk.
// - mmap_create: allocates shared region
// - mmap_write:  memcpy from BEAM binary → mmap  (1 copy)
// - mmap_sort:   sorts in-place in mmap           (0 copies)
// - mmap_read:   memcpy from mmap → new binary    (1 copy)
//
// The sort step itself is truly zero-copy. The benchmark measures
// both the full cycle (write+sort+read) and sort-only.
// =============================================================================
struct MmapResource {
    mmap: Mutex<memmap2::MmapMut>,
    num_elements: usize,
}

#[rustler::resource_impl]
impl Resource for MmapResource {}

#[rustler::nif]
fn mmap_create(num_elements: usize) -> ResourceArc<MmapResource> {
    let size = num_elements * std::mem::size_of::<i64>();
    let file = std::fs::OpenOptions::new()
        .read(true)
        .write(true)
        .create(true)
        .truncate(true)
        .open("/dev/shm/sorting_bench_mmap")
        .expect("failed to open /dev/shm file");
    file.set_len(size as u64).expect("failed to set file length");

    let mmap = unsafe { memmap2::MmapMut::map_mut(&file).expect("mmap failed") };

    ResourceArc::new(MmapResource {
        mmap: Mutex::new(mmap),
        num_elements,
    })
}

#[rustler::nif]
fn mmap_write(resource: ResourceArc<MmapResource>, binary: Binary) -> Atom {
    let mut mmap = resource.mmap.lock().unwrap();
    let len = binary.as_slice().len().min(mmap.len());
    mmap[..len].copy_from_slice(&binary.as_slice()[..len]);
    atoms::ok()
}

#[rustler::nif(schedule = "DirtyCpu")]
fn mmap_sort(resource: ResourceArc<MmapResource>) -> Atom {
    let mut mmap = resource.mmap.lock().unwrap();
    let slice = unsafe {
        std::slice::from_raw_parts_mut(
            mmap.as_mut_ptr() as *mut i64,
            resource.num_elements,
        )
    };
    slice.sort_unstable();
    atoms::ok()
}

#[rustler::nif]
fn mmap_read(resource: ResourceArc<MmapResource>) -> OwnedBinary {
    let mmap = resource.mmap.lock().unwrap();
    let size = resource.num_elements * std::mem::size_of::<i64>();
    let mut owned = OwnedBinary::new(size).unwrap();
    owned.as_mut_slice().copy_from_slice(&mmap[..size]);
    owned
}

rustler::init!("Elixir.SortingBench.RustNif");
