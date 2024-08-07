# Odin Renderdoc

Renderdoc api loader in odin

# Usage

1. you need to have renderdoc installed to load it
2. you need to call renderdoc.load_api() from your startup code to load it
3. look at example/main.odin to see usage, F1/F2/F3 - captures and open Renderdoc UI
4. use the compiler define -define:LOAD_RENDERDOC=false to strip away renderdoc while building

Loads renderdoc, add this during your startup

```go
// pass in the path to renderdoc if not installed in default location of "C:/Program Files/RenderDoc"
rdoc_lib, rdoc_api, rdoc_ok := rdoc.load_api(/*"C:/Program Files/RenderDoc"*/)
// cast to a specific api struct to directly use the api, without the wrapper
// typed_rdoc_api := cast(^rdoc.API_1_6_0) rdoc_api
if rdoc_ok {
	log.infof("loaded renderdoc %v", rdoc_api)
} else {
	log.warn("couldnt load renderdoc")
}
defer rdoc.unload_api(rdoc_lib)

rdoc.SetCaptureFilePathTemplate(rdoc_api, "captures/capture.rdc")

// uncomment if you want to disable default behaviour of renderdoc capture keys
// rdoc.SetCaptureKeys(rdoc_api, nil, 0)
```

Call this appropriately to open RenderdocUI with the latest capture, see example/main.odin for more

```go
LaunchOrShowRenderdocUI :: proc(rdoc_api: rawptr) {
	latest_capture_index := rdoc.GetNumCaptures(rdoc_api) - 1
		
	if latest_capture_index < 0 {
		return
	}

	timestamp: u64
	capture_file_path := make([]u8, 512, context.temp_allocator)
	defer delete(capture_file_path, context.temp_allocator)
	capture_file_path_len: u32

	if rdoc.GetCapture(rdoc_api, latest_capture_index, transmute(cstring)raw_data(capture_file_path), &capture_file_path_len, &timestamp) != 0 {
		assert(capture_file_path_len < 512, "too long capture path!!")
		current_directory := os.get_current_directory(context.temp_allocator)
		defer delete(current_directory, context.temp_allocator)
	
		abs_capture_path := filepath.join([]string{current_directory, transmute(string)capture_file_path}, context.temp_allocator)
		defer delete(abs_capture_path, context.temp_allocator)

		log.infof("loading latest capture: %v", abs_capture_path)
		
		if rdoc.IsTargetControlConnected(rdoc_api) {
			rdoc.ShowReplayUI(rdoc_api)
		} else {
			pid := rdoc.LaunchReplayUI(rdoc_api, 1, transmute(cstring)raw_data(abs_capture_path))
			if pid == 0 {
				log.error("couldn't launch Renderdoc UI")
				return
			}
			log.infof("launched Renderdoc UI pid(%v)", pid)
		}
	} else {
		log.warnf("no valid capture exists to load")
	}
}
```

# How to add to your project

## Using git submodules
```git submodule add https://github.com/2nafish117/odin-renderdoc thirdparty/odin-renderdoc```

## Download zip
download zip and paste it into your project
