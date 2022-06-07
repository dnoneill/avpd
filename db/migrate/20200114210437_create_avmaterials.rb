class CreateAvmaterials < ActiveRecord::Migration[5.1]
  def change
    create_table :avmaterials do |t|
      t.string :inputpath
      t.string :outputpath
      t.string :converted
      t.text :processerror
      t.string :avtype
      t.string :slug, null: false
      t.timestamps
    end
    add_index :avmaterials, :slug, unique: true
  end
end
