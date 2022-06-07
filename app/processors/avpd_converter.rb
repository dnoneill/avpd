class AvpdConverter
  include AvHelper
  require 'etc'
  require 'fileutils'
  require 'open3'
  require 'pocketsphinx-ruby'
  require 'streamio-ffmpeg'
  require "ibm_watson"
  require 'json'

  def initialize(args)
    @inputpath = args[:inputpath]
    @outputpath = args[:outputpath] && !args[:outputpath].empty? ? args[:outputpath] : ENV['avoutputpath']
    @processor = args[:processor]
    @basename = getSlug(@inputpath)
    @outputfilepath = File.join(@outputpath, @basename)
    @outputpath_without_extension = File.join(@outputfilepath, @basename)
    @avmaterial = Avmaterial.find_by(inputpath: @inputpath)
    silence_data = @avmaterial.silencedata ? JSON.parse(@avmaterial.silencedata) : []
    if silence_data[0] && silence_data[0]['start'] == 0 && !args[:starttime]
      @addtime = silence_data[0]['end']
    elsif args[:starttime]
      @addtime = args[:starttime].to_f
    else
      @addtime = 0
    end
  end

  def buildConversion()
    if !File.exist?(@outputfilepath)
      FileUtils.mkdir_p @outputfilepath
    end
    @avmaterial.outputpath = @outputfilepath
    @avmaterial.converted = 'converting'
    @avmaterial.save

    extension = @avmaterial.avtype == 'audio' ? '.mp3' : '.mp4'
    @processingpath = "#{@outputpath_without_extension}#{extension}"
    if @processor
      if @processor.include?('sprite') && @avmaterial.avtype != 'audio'
        spriteprocessor()
      end
      if @processor.include?('caption')
        speechtotext()
      end
      if @processor.include?('ffmpegdata')
        populateffmpegfields()
      end
    elsif @avmaterial.avtype == "audio"
      convertaudio()
    else
      convertvideos()
    end
  end

  def populateffmpegfields()
    path = File.file?(@processingpath) ? @processingpath : @inputpath
    ffmpegresults = ffmpegdata(path)
    @avmaterial.ffmpeginfo = ffmpegresults.to_json
    startendlist = startendsilences(path, ffmpegresults)
    silence_data = JSON.parse(startendlist[:silencedata].to_json)
    if silence_data[0] && silence_data[0]['start'].to_i == 0 && @addtime.to_i == 0
      @addtime = silence_data[0]['end'].to_f
    end
    @avmaterial.silencedata = silence_data.to_json
    @avmaterial.issilent = startendlist[:issilent]
    @avmaterial.save
    if !@avmaterial.issilent
      waveformdata(path, "#{@outputpath_without_extension}.json")
    end
  end

  def secstovttformat(sec)
    seconds, point = sec.to_s.split(".")
    point = point.nil? ? "0" : point
    Time.at(seconds.to_i).utc.strftime("%H:%M:%S") + '.' + point[0..2].ljust(3, "0")
  end

  def parsetovttibm(future)
    alltext = []
    future.value.result['results'].each do |result|
      timestamps = result['alternatives'][0]['timestamps']
      timestamps.each_with_index do |timestamplist, index|
        alltext.push({'starttime':timestamplist[1],  'endtime': timestamplist[2], 'word': timestamplist[0].gsub('%HESITATION', '').strip})
      end
    end

    writevttfile(alltext, 'IBM Watson')
  end

  def speechtotext()
    begin
      @avmaterial = Avmaterial.find_by(inputpath: @inputpath)
    rescue
      ActiveRecord::Base.connection.reconnect!
      @avmaterial = Avmaterial.find_by(inputpath: @inputpath)
    end
    populateffmpegfields()
    if @avmaterial.vtteditors.length == 0 && !@avmaterial.issilent && !@avmaterial.transcript.present? && ENV['caps_limit_reached'] != 'true'
      ffmpegtranscode = FFMPEG::Movie.new(@processingpath)
      ibm_watson = ENV['ibm_api_key'] ? true : false
      tmpfileextension = ibm_watson ? '.ogg' : '.wav'
      tmpfilecodec = ibm_watson ? 'libopus' : 'pcm_s16le'
      tmpfile = Tempfile.new([@basename, tmpfileextension])
      transcodelist = %W(-vn -acodec #{tmpfilecodec} -ar 16000 -ac 1)
      if @addtime != 0
        transcodelist.push('-ss')
        transcodelist.push(@addtime.to_s)
      end
      ffmpegtranscode.transcode(tmpfile.path, transcodelist)
      if ibm_watson
        authenticator = IBMWatson::Authenticators::IamAuthenticator.new(apikey: ENV['ibm_api_key'])
        speech_to_text = IBMWatson::SpeechToTextV1.new(authenticator: authenticator)
        audio_file = File.open(tmpfile.path)
        future = speech_to_text.await.recognize(
          audio: audio_file,
          timestamps: true
        )
        if !future.value || (future.value && !future.value.result) || (future.value && future.value.result && !future.value.result['results'])
          tmpfile.unlink
          raise "Caption render error: no value in ibm watson return. #{future.inspect} #{future.value.inspect}"
        else
          parsetovttibm(future)
        end
      elsif ENV['deepspeechmodels']
        puts 'deepspeech start'
        deepspeech = "deepspeech --model #{File.join(ENV['deepspeechmodels'], '*.pbmm')} --scorer #{File.join(ENV['deepspeechmodels'], '*.scorer')} --audio #{tmpfile.path} --json"
        convertstdout, convertstderr, convertstatus = Open3.capture3(deepspeech)
        puts 'deepspeech end'
        if convertstdout != ""
          parsedeepspeech(convertstdout)
        else
          tmpfile.unlink
          raise "Caption render error: #{convertstderr}"
        end
      else
        puts "pocketsphinx start"
        pocketsphinx = "pocketsphinx_continuous -infile #{tmpfile.path} -time true -remove_noise yes"
        convertstdout, convertstderr, convertstatus = Open3.capture3("#{pocketsphinx}")
        puts "pocketsphinx end"
        if convertstdout != "" 
          parsetovttsphinx(convertstdout)
        else
          tmpfile.unlink
          raise "Caption render error: #{convertstderr}"
        end
      end
      tmpfile.unlink
    end
  end

  def parsedeepspeech(convertstdout)
    parsed = JSON.parse(convertstdout)
    alltext = []
    parsed['transcripts'][0]['words'].each do |worddict|
      endtime = worddict['start_time '].to_f + worddict['duration'].to_f
      alltext.push({'starttime':worddict['start_time '],  'endtime': endtime, 'word': worddict['word'] ? worddict['word'].gsub(/\([1-9]\)/, "") : ''})
    end
    writevttfile(alltext, 'Mozilla DeepSpeech')
  end

  def parsetovttsphinx(convertstdout)
    parsed_data = convertstdout.gsub("\n<s>", " discard\n<s>").gsub("</s>", "").split("<s>")
    alltext = []
    parsed_data.each do |spath|
      lines = spath.split("\n").select{|item|!item.include? "discard"}
      lines.each_with_index do |line, index|
        linesplit = line.split(" ")
        word = linesplit.length == 4 ? linesplit[0].gsub("<sil>", "[SILENCE]") : ""
        starttime = linesplit.length == 4 ? linesplit[1] : linesplit[0]
        endtime = linesplit.length == 4 ? linesplit[2] : linesplit[1]
        alltext.push({'starttime':starttime,  'endtime': endtime, 'word': word.gsub(/\([1-9]\)/, "")})
      end
    end
    writevttfile(alltext, 'PocketSphinx')
  end

  def parsedict(alltext, parser)
    starttime = alltext[0][:starttime].to_f
    text = ''
    while starttime < alltext[-1][:endtime].to_f
      textitems = alltext.select { |item|item[:starttime].to_f >= starttime && item[:endtime].to_f <= (starttime + 8.0) }
      if textitems.length > 0
        sentence = textitems.map{|elem|elem[:word]}.join(" ").gsub(/\s+/, " ").strip
        if !sentence.empty?
          vttstarttime = textitems[0][:starttime].to_f + @addtime
          vttendtime = textitems[-1][:endtime].to_f + @addtime
          text += "#{secstovttformat(vttstarttime)} --> #{secstovttformat(vttendtime)}\n"
          text += "#{sentence}\n\n"
        end
        starttime = textitems[-1][:endtime].to_f
      else
        starttime += 0.1
      end
    end
    return "WEBVTT\nNOTE: This file was automatically generated with #{parser}\n\n#{text}"
  end

  def writevttfile(alltext, parser)
    if alltext.length > 0
      writevtttext = parsedict(alltext, parser)
      vttfilepath = "#{@outputpath_without_extension}.vtt"
      writetofile(vttfilepath, writevtttext)
    end
  end

  def writetofile(filepath, text) 
    File.open(filepath, 'w') { |file|
      file.write(text)
    }
  end

  def convertaudio()
    audio = FFMPEG::Movie.new(@inputpath)
    audio.transcode("#{@outputpath_without_extension}.mp3") { |progress| puts progress*100 }
    audio.transcode("#{@outputpath_without_extension}.ogg") { |progress| puts progress*100 }
    speechtotext()
  end

  def spriteprocessor() 
    options = {
      seconds: 5,
      width: 160,
      columns: 4,
      group: 20,
      gif: false,
      keep_images: false,
      basename: "#{@basename}-sprite"
    }
    
    processor = VideoSprites::Processor.new("#{@outputpath_without_extension}.mp4", @outputfilepath, options)
    processor.process
  end
  
  def convertvideos()   
    movie = FFMPEG::Movie.new(@inputpath) 
    if !@avmaterial.poster.present? || @avmaterial.poster['id'] == ENV['default_poster']
      movie.screenshot("#{@outputpath_without_extension}.png", { seek_time: 5, resolution: movie.resolution}, preserve_aspect_ratio: :width)
    end
    channelmap = movie.metadata[:streams].present? && movie.metadata[:streams].length > 0 ? movie.metadata[:streams].select{|stream|stream[:codec_type] == 'audio'} : []
    webmcommand = %W(-c:v libvpx -crf 10 -b:v 1M -filter:v scale=#{ENV['derivativewidth']}:trunc(ow/a/2)*2 -c:a libopus -b:a 128k)
    mp4command = %W(-c:v libx264 -preset slow -crf 23 -profile:v baseline -level 3.0 -filter:v scale=#{ENV['derivativewidth']}:trunc(ow/a/2)*2 -acodec aac -b:a 128k -movflags +faststart -pix_fmt yuv420p)
    if channelmap.length > 0 && channelmap[0][:channel_layout] && channelmap[0][:channel_layout].gsub(/[^0-9.]/, '').present?
      mp4command.push('-af')
      mp4command.push("channelmap=channel_layout=#{channelmap[0][:channel_layout].gsub(/[^0-9.]/, '')}")
      webmcommand.push('-af')
      webmcommand.push("channelmap=channel_layout=#{channelmap[0][:channel_layout].gsub(/[^0-9.]/, '')}")
    end
    movie.transcode("#{@outputpath_without_extension}.mp4", mp4command) { |progress| puts progress*100 }
    movie.transcode("#{@outputpath_without_extension}.webm", webmcommand) { |progress| puts progress*100 }
    spriteprocessor()
    speechtotext()
  end
end
