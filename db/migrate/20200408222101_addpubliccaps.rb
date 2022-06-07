class Addpubliccaps < ActiveRecord::Migration[5.1]
  def change
    add_column :avmaterials, :publiccaps, :boolean, :default => false
  end
end
