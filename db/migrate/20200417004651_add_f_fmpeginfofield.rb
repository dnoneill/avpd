class AddFFmpeginfofield < ActiveRecord::Migration[5.1]
  def change
    add_column :avmaterials, :ffmpeginfo, :text
    add_column :avmaterials, :silencedata, :text
    add_column :avmaterials, :issilent, :boolean, :default => false
  end
end
