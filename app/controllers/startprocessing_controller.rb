require 'net/http'
require 'uri'
class StartprocessingController < ApplicationController
  def index
  end
  def start
    filepath = File.join(ENV['inputpath'], params[:inputpath])
    @ApiController = ApiController.new
    apiparams = {"avfilepath" => filepath, "outputpath" => params[:outputpath]}
    check = @ApiController.checkpath(apiparams)
    if check['failed']
      render :template => "startprocessing/index", :locals => {:errors=> "No files existing in <b>#{filepath}</b>. Please try again."}
    else
      @ApiController.process_files(apiparams, true)
      redirect_to :controller => "av", :action => "index"
    end
  end
end
