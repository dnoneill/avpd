class Changetextlimits < ActiveRecord::Migration[5.2]
  def change
    change_column :avmaterials, :ffmpeginfo, :text, limit: 16.megabytes - 1
    change_column :avmaterials, :silencedata, :text, limit: 16.megabytes - 1
    change_column :avmaterials, :processerror, :text, limit: 16.megabytes - 1
  end
end
