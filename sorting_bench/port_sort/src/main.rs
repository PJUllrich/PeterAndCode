//! Port-based sorter: reads packed i64s from stdin, sorts, writes to stdout.
//!
//! Protocol (length-prefixed framing):
//!   Input:  4 bytes (big-endian u32 length N) + N bytes of packed native-endian i64s
//!   Output: 4 bytes (big-endian u32 length N) + N bytes of sorted packed native-endian i64s
//!
//! The BEAM Port sends/receives with `{:packet, 4}` which handles the framing.

use std::io::{self, Read, Write};

fn main() -> io::Result<()> {
    let stdin = io::stdin();
    let stdout = io::stdout();
    let mut stdin = stdin.lock();
    let mut stdout = stdout.lock();

    loop {
        // Read 4-byte length header
        let mut len_buf = [0u8; 4];
        match stdin.read_exact(&mut len_buf) {
            Ok(()) => {}
            Err(e) if e.kind() == io::ErrorKind::UnexpectedEof => break,
            Err(e) => return Err(e),
        }
        let len = u32::from_be_bytes(len_buf) as usize;

        // Read the payload
        let mut data = vec![0u8; len];
        stdin.read_exact(&mut data)?;

        // Interpret as native-endian i64s and sort
        let num_elements = len / std::mem::size_of::<i64>();
        let slice = unsafe {
            std::slice::from_raw_parts_mut(data.as_mut_ptr() as *mut i64, num_elements)
        };
        slice.sort_unstable();

        // Write length header + sorted data
        stdout.write_all(&len_buf)?;
        stdout.write_all(&data)?;
        stdout.flush()?;
    }

    Ok(())
}
