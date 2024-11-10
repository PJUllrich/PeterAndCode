defmodule HabitWeb.Layouts.SwiftUI do
  use HabitNative, [:layout, format: :swiftui]

  embed_templates "layouts_swiftui/*"
end
