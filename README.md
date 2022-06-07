# A/V transcoding

# Note
This README is assuming that you are using this application with the Vagrant machine in the application folder. In the Vagrant machine, everything in this folder gets put into the path `/vagrant` on the Vagrant machine. If you are not using the Vagrant machine, you are going to want to update the application settings outlined in the Customization section below. 

# About
This is a rails application which has been set up to process Audio and Visual materials. It makes a couple of assumptions. 

1. The name of the media file is the slug. So `filetoconvert.mp4` would have a slug of `filetoconvert`
2. The output will be in a folder with the name of the slug and all the files will have the slug name: i.e. `fileconvert/fileconver.webm, fileconvert/fileconvert.mp4, fileconvert/fileconver.vtt, etc.` 

# Customizations
The customizations are set in the config/applications.yml file. Important fields to keep in mind:

1. SpeechToText processor. `ibm_api_key` and `deepspeechmodels`. Speech to Text is set up to be compatible with IBM Watson, Deepspeech or CMU Sphinx. The default is CMU Sphinx. If you want to use IBM Watson add the API key Watson provides in the `ibm_api_key` field. If you want to enable deepspeech put in the path to the deepspeech models you want to use in `deepspeechmodels`, if using the vagrant machine that comes with this application, they automatically get created in the deepspeach folder. If you are doing this manually, make sure you have the `.pbmm` and `.scorer` files. Keep in mind the application has a hierarchy for speech to text. It will use IBM Watson if there is a key, then deepspeech, then CMU Sphinx. If you want to go from IBM Watson to CMU Sphinx **you must comment out or delete `ibm_api_key`**.

2. Output. `avoutputpath` will determine the folder where the files will get output by default. You can override this output path with the output path field on the [process av materials page](http://localhost:3333/startprocessing) or when using the API, the `outputpath` parameter. This needs to always be set. By default it is set to: /vagrant/public/processedav.

3. Pagination. `per_page` determines how many results show up in a page. Default is 100.

4. Host URL. `host_url`. This will help some basic tooling.

5. Ignore path. `ignorepath` this is for building the API paths. For example, if the outputpath is `/nested/folder/fileconvert/av/fileconvert/fileconvert.mp4` and the URL for the digital surrogate is `https://example.com/av/fileconvert/fileconvert.mp4` you will need to have an `ignorepath` of `/nested/folder/`. Otherwise it is not necessary.

6. Default poster. `default_poster` since this is also handles Audio materials there is a `default_poster` variable. The default poster gets overridden when a poster is created or uploaded.

7. Inputpath path. `inputpath` defines the default inputpath of all av material.

8. Filetypes. `audiofiletypes` and `avtypes`. `avtypes` is a list of files the application looks for to convert. `audiofiletypes` defines which file types are audio (this is for the application to determine avtype). These should have almost all avtypes and should not need to be updated. 

9. Derivative width. By default: '640'. This setup is a little bit weird because of how FFMPEG (what is being used to create deriviates) works. This basically works the following way. It will format all videos to 640x480 if the original video's dimensions scale down to that dimension correctly. If the video does not have the correct dimensions to scale down to 640x480, the width will get reset to the correct dimension for the original video x480. For example, if the original video is 1706 × 960, the new videos is going to be: 853x480.

10. APP_API_KEY. This should only be used if you are integrating with another application and that application has a specific API key.


# Integrating with other applications
AVPD is set up so that it can be used with other applications. This application has been set up at NC State University libraries to be a node of our workflow orchestration application for special collections. The API for processing materials is set up in such a way that you can communicate with other applications. The API has the following variables that can be sent in data.

- `avfilepath`: (required). The filepath for the files you want to process, this should be a folder. The application will grab all A/V materials in nested folders. For example, if you have a folder named avitems and there are two folders in avitems, the application will grab all av materials from both of the folders and process the materials.
This variable can also be used to process a single file. If you want to process a single file make sure to include the full filepath with the extension i.e. [/filepath/to/a/file/audiofile.wav]. The application will not be able to auto detect single files without an AV extension (everything after the period).
- `response_url`: (optional). When the files are finished processing, the URL the application will send a patch request to the URL. What gets sent to the response url is listed below. Additionally, in the customizations, you can set an APP_API_KEY. The APP_API_KEY gets sent in the headers ('API-KEY') to the response url. This allows you to set up authenication on your receiving URL.
    - if there are errors: {"derivatives_complete" => false, "errors" => [a list of failed files with the failure message] }
    - if all files successfully processed: {"derivatives_complete" => true, "derivatives"=> [list of slugs for all the derivaties]}}
- `outputpath`: (optional). The output path of the files being processed.
- `processor`: (optional). Options are `sprites`, `captions`, `ffmpegdata`. This allows you to only run the process to create sprites (`sprites`), create captions (`captions`) or populate the ffmpegdata (height, duration, silences, etc.) about the materials. This will skip the deriviative making process and only run the process for these specific items. Note: ffmpegdata gets automatically updated when running `captions` and `sprites`.

# Requirements

1. [Vagrant](https://www.vagrantup.com/downloads.html)
2. [VirtualBox](https://www.virtualbox.org/wiki/Downloads)

## Quick Start
### Installation

**Quick note about code syntax. The $ sign is to indicate code that should be run in the command line/terminal. You should only copy everything after the $ sign. Your command line/terminal might not have the $ symbol based on how you have your machine set up. Also [vagrant]$ indicates you are no longer in your local machine, and are in the vagrant machine.  You should only copy everything after the $ sign in these code blocks as well.**

1. Clone repository

```
$ git clone https://github.ncsu.edu/ncsu-libraries/avtranscode.git && cd avtranscode
```

2. Start Vagrant

```
$ vagrant up
```

3. SSH into Vagrant, run the code below (everything after the $ sign).

Note: For the command: `rake resque:restart_workers[1,"patchrequest\,avpdconverter"]`, the number 1 is the number of workers, you can increase this number if you want more workers. The number of workers will inform how things get processed. For example, you upgrade 2 workers, two items will get processed at the same time. **You will need to run this line if you update the application.yml file**

```
$ vagrant ssh
[vagrant]$ rake resque:restart_workers[1,"patchrequest\,avpdconverter"]
[vagrant]$ bundle exec rails s -b 0.0.0.0
```

There are two ways to process materails:

1. In terminal or with another application, send request to the API.

```
$ curl -d '{"avfilepath":"/vagrant/avfiles"}' -H "Content-Type: application/json" -X POST http://localhost:3333/api/convert
```

OR

```
$ curl -d '{"avfilepath":"/vagrant/avfiles/2830-3980-0043.wav"}' -H "Content-Type: application/json" -X POST http://localhost:3333/api/convert
```

2. In browser. Got to http://localhost:3333/startprocessing and enter in correct filepaths.


### Links in Application:

1. http://localhost:3333/av will display all av materials and the status of the materials
2. http://localhost:3333/av/[slug], (slug is defined in About section, item #2) will button to reporcess material, edit/create captions link, upload captions, create captions using transcript link, choose poster link, upload poster, and upload PDF transcript. Then the display the av materials in a viewer. Additionally, it provides an embed code HTML, output path, avtype, creation, updated and data on public captions metadata.
3. http://localhost:3333/api/av/[slug] will display a JSON API of the data associated with that record.
4. http://localhost:3333/av/[slug]/edit will display a caption editor, with a button to `Make Public` or `Make Private` captions.
5. http://localhost:3333/transcript/[slug] will display the text of the caption file.
5. http://localhost:3333/embed/[slug] will display the embedable version of the av viewer.
5. http://localhost:3333/startprocessing will provide a form to enter the paths of the items that need to be processed.
6. http://localhost:3333/resque shows resque information (items to be processed and their status).
7. http://localhost:3333/api/search?q=[query+search]&captions=[all, public, private]. API to search captions. By default will search all captions, even those not public. This can be changed in the optional captions parameter.