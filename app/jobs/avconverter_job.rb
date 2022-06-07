class AvconverterJob < ApplicationJob
  queue_as :avpdconverter
  @queue = :avpdconverter
  include AvHelper

  before_enqueue do |job|
    basename = getSlug(job.arguments[0][:inputpath])
    avmaterial = Avmaterial.find_by(slug: basename)
    avmaterial.converted = 'inqueue'
    avmaterial.save
  end

  def perform(args)
    begin
      image_init = AvpdConverter.new(args)
      image_init.buildConversion()      
    rescue => error
      avmaterial = Avmaterial.find_by(inputpath: args[:inputpath])
      avmaterial.processerror = error.to_s
      convertstatus = error.to_s.include?('Caption render error') ? 'captionerror' : 'false'
      avmaterial.converted = convertstatus
      avmaterial.save
      if convertstatus == 'false'
        raise error
      end
    else
      avmaterial = Avmaterial.find_by(inputpath: args[:inputpath])
      avmaterial.converted = 'true'
      avmaterial.processerror = nil
      avmaterial.save
    end
  end
end
