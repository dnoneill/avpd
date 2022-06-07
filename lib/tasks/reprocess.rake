namespace :reprocess do
  desc "Rake task to reprocess any failed items."
  task failures: :environment do
    failures = Avmaterial.where(converted: ['false', 'inqueue'])
    failures.each do |failure|
      inputpath = failure.inputpath
      if !failure.avmaterial 
          AvconverterJob.perform_later({:inputpath=>inputpath})
      else 
        if !failure.captions.present?
          AvconverterJob.perform_later({:inputpath=>inputpath, :processor => 'caption'})
        end
        if !failure.sprites.present? 
          AvconverterJob.perform_later({:inputpath=>inputpath, :processor => 'sprite'})
        end
        if !failure.ffmpeginfo.present?
          AvconverterJob.perform_later({:inputpath=>inputpath, :processor => 'ffmpegdata'})
        end
      end
    end
  end

end
