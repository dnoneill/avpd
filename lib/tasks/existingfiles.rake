namespace :existingfiles do
  desc "If you already have av derivatives created and you want to import them into AVPD, run this task with the filepath for those derivatives."
  task :import, [:filepath] => [:environment] do |t, args|
    include AvHelper
    filepath = args[:filepath] ? args[:filepath] : ENV['avoutputpath'];
    avfiles = Dir.glob(create_filepath(filepath)).select{|item|!item.include?'_tmp'}.map{|path|File.dirname(path)}.uniq
    basenames = avfiles.map{|path| { 'slug' => getSlug(path), 'path' => path } }
    basenames.each do |file|
      begin
        if Avmaterial.where(slug: file['slug']).empty?
          extension = File.extname(Dir.glob(create_filepath(file['path']))[0]).delete('.').downcase
          avtype = ENV['audiofiletypes'].split(",").include?(extension) ? "audio" : "video"
          outputpath = File.dirname(file['path'])
          av = Avmaterial.create(:slug => file['slug'], :inputpath => file['path'], :outputpath => file['path'],:converted => 'true', :avtype=> avtype)
          av.save
          if !av.captions.present?
            AvconverterJob.perform_later({:inputpath=>file['path'], :outputpath => outputpath, :processor => 'caption'})
          end
          if !av.sprites.present?
            AvconverterJob.perform_later({:inputpath=>file['path'], :outputpath => outputpath, :processor => 'sprite'})
          end
          if av.sprites.present? && av.captions.present? && !av.ffmpeginfo
            AvconverterJob.perform_later({:inputpath=>file['path'], :outputpath => outputpath, :processor => 'ffmpegdata'})
          end
        end
      rescue => error
        avmaterial = Avmaterial.find_by(slug: file['slug'])
        avmaterial.processerror = error.to_s
        avmaterial.converted = 'false'
        avmaterial.save
        raise error
      end
    end
  end
end
