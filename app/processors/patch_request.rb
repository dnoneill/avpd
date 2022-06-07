require 'net/http'
require 'uri'
class PatchRequest
  def initialize(args)
    @items  = args[:files]
    @response_url = args[:response_url]
  end

  def preconditions_met()
    currentjobs = Resque.workers.map { |w| w.job() }
    currentjobs = currentjobs.map { | element |  element['queue'] === 'avpdconverter' ? getInputPath(element) : '' }
    inqueue = Resque.redis.lrange('queue:avpdconverter', 0, -1)
    inqueue = inqueue.map {| element | getInputPath(Resque.decode(element)) }
    currently = currentjobs.concat(inqueue).uniq
    return (currently & @items).empty?
  end

  def getInputPath(queueitem)
    basepath = queueitem['args'] ? queueitem : queueitem['payload']
    return basepath['args'][0]['arguments'][0]['inputpath']
  end

  def send_request()
    failed = []
    warnings = []
    @items.each do |item|
      dbitem = Avmaterial.find_by inputpath: item
      if dbitem.processerror
        if !dbitem.processerror.include?('Caption render error')
          failed.push("#{dbitem.inputpath}: #{dbitem.processerror}")
        else
          warnings.push("#{dbitem.inputpath}: caption not built. Check AVPD for more information.")
        end
      end
    end
    if failed.length > 0
      body = {"derivatives_complete" => false, "errors" => failed, "warnings" => warnings }
    else
      body = {"derivatives_complete" => true, "derivatives"=> @items.map{|elem| Avmaterial.where(inputpath: elem).first.slug}, "warnings" => warnings}
    end
    if @response_url && !@response_url.empty?
      uri = URI.parse(@response_url)
      req = Net::HTTP::Patch.new(uri)
      req['API-KEY'] = ENV['APP_API_KEY']
      req['Content-Type'] = 'application/json'
      req.body = body.to_json
      response = Net::HTTP.start(uri.hostname, uri.port, :use_ssl => true) do |http|
        request = http.request(req)
      end
    else
      puts body.inspect
    end
  end
end
