class PatchrequestJob < ApplicationJob
  queue_as :patchrequest
  @queue = :patchrequest

  def perform(items)
    patch_init = PatchRequest.new items
    if patch_init.preconditions_met()
      patch_init.send_request()
    else
      seconds = (items[:files].length/20.0)*60
      PatchrequestJob.set(wait: seconds.seconds).perform_later(items)
    end
  end
end
