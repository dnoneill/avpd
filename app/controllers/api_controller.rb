class ApiController < ApplicationController
    include AvHelper

    def convert
      status = checkpath(params)
      if status['failed']
        render_error(status)
      else
        process_files(params)
      end
    end

    def context
      respond_to do |format|
        format.html
        format.json
      end
    end

    def checkpath(params)
      globpath = create_filepath(params['avfilepath'])
      if !globpath 
        return {'failed' => true, 'message' => 'Missing parameter "avfilepath", send request with requested information'}
      elsif Dir.glob(globpath).length == 0
        return {'failed' => true, 'message' => "#{globpath} contains no files" }
      else
        return {'failed' => false, 'message'=> globpath.length}
      end
    end

    def render_error(message)
        status = 400  
        render json: {error: { status: status, detail: message }}, status: status
    end

    def show_av
      av_data = Avmaterial.find_by(slug: params[:av_id])
      render json: AvSerializer.new(av_data).to_json
    end

    def process_files(params, rake=false)
      filepath = create_filepath(params['avfilepath'])
      filelist = Dir.glob(filepath)
      filelist.sort.each do |avpath|
        jobs = Avmaterial.where(:converted => 'inqueue').or(Avmaterial.where(:converted => 'converting'))
        jobitems = jobs.map{|job|job.inputpath}
        if !jobitems.include? avpath
          avmaterial = Avmaterial.find_or_create_by(slug: getSlug(avpath))
          avtype = ENV['audiofiletypes'].split(",").include?(File.extname(avpath).delete('.').downcase) ? "audio" : "video"
          avmaterial.avtype = avtype
          avmaterial.inputpath = avpath
          avmaterial.converted = 'loaded'
          avmaterial.save
          AvconverterJob.perform_later({:inputpath=>avpath, :outputpath => params['outputpath'], :processor => params['processor']})
        end
      end
      PatchrequestJob.perform_later({files: filelist, response_url: params['response_url']})
      if !rake
        render json: { status: 200, detail: 'Files recieved and processing' }, status: 200
      end
    end

    def fulltextsearch
      searchterm = params[:q].downcase
      @results = []
      captionvalue = params[:captions] == 'private' ? false : params[:captions] == 'public' ? true : ''
      avmaterials = captionvalue == '' ? Avmaterial.all : Avmaterial.where("publiccaps": captionvalue)
      avmaterials.each do |av|
        transcript = getTranscript(av)
        if transcript.present?
          valuedict = AvSerializer.new(av).to_h
          valuedict['fulltext'] = transcript
          valuedict['publiccaps'] = av.publiccaps
          transcript = transcript.downcase
          terms = searchterm.split(" ").select{|elem|elem.length > 3}
          termresults = transcript.scan(/#{terms.join("|") }/).reject(&:empty?)
          if transcript.include?(searchterm)
            scanresults = transcript.scan(/#{searchterm}/).reject(&:empty?)
            valuedict['score'] = scanresults.count * 10 + termresults.count
            @results.push(valuedict)
          elsif termresults.count > 0
            multiplier = terms.uniq == termresults.uniq ? 2 : 1
            valuedict['score'] = termresults.count * multiplier
            @results.push(valuedict)
          end
        end
      end
      render json: @results.sort_by { |k| k["score"] }.reverse.to_json, status: 200
    end
end
