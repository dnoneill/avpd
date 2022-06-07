class CreateAvVttFields < ActiveRecord::Migration[5.2]
  def change
    add_column :avmaterials, :vtteditors, :string, default: [].to_yaml
    add_column :avmaterials, :vttlastmodified, :date
  end
end
