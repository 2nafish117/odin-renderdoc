package main

import "core:log"
import "core:fmt"
import "base:runtime"
import "core:c"
import "vendor:glfw"
import "core:os"
import "core:path/filepath"
import gl "vendor:OpenGL"

import rdoc ".."

RenderDocCaptureStage :: enum {
	None,
	Capture,
	Trigger,
	TriggerMulti,
	Waiting,
	LaunchUI,
}

rdoc_stage: RenderDocCaptureStage = .None

KeyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
	// handle showing ui
	if key == glfw.KEY_F1 && action == glfw.PRESS {
		rdoc_stage = .Capture
	}
	if key == glfw.KEY_F2 && action == glfw.PRESS {
		rdoc_stage = .Trigger
	}
	if key == glfw.KEY_F3 && action == glfw.PRESS {
		rdoc_stage = .TriggerMulti
	}
}

LaunchOrShowRenderdocUI :: proc(rdoc_api: ^rdoc.RENDERDOC_API_1_6_0) {
	latest_capture_index := rdoc_api.GetNumCaptures() - 1
		
	if latest_capture_index < 0 {
		return
	}

	timestamp: u64
	capture_file_path := make([]u8, 512, context.temp_allocator)
	defer delete(capture_file_path, context.temp_allocator)
	capture_file_path_len: u32

	if rdoc_api.GetCapture(latest_capture_index, transmute(cstring)raw_data(capture_file_path), &capture_file_path_len, &timestamp) != 0 {
		assert(capture_file_path_len < 512, "too long capture path!!")
		current_directory := os.get_current_directory(context.temp_allocator)
		defer delete(current_directory, context.temp_allocator)
	
		abs_capture_path := filepath.join([]string{current_directory, transmute(string)capture_file_path}, context.temp_allocator)
		defer delete(abs_capture_path, context.temp_allocator)

		log.infof("loading latest capture: %v", abs_capture_path)
		
		if rdoc_api.IsTargetControlConnected() == 1 {
			rdoc_api.ShowReplayUI()
		} else {
			pid := rdoc_api.LaunchReplayUI(1, transmute(cstring)raw_data(abs_capture_path))
			if pid == 0 {
				log.error("couldn't launch Renderdoc UI")
				return
			}
			log.infof("launched Renderdoc UI pid(%v)", pid)
		}
	}
	else {
		log.warnf("no valid capture exists to load")
	}
}

main :: proc() {
	context.logger = log.create_console_logger()

	rdoc_lib, rawptr_rdoc_api, rdoc_ok := rdoc.load_api()
	rdoc_api := cast(^rdoc.RENDERDOC_API_1_6_0) rawptr_rdoc_api
	if rdoc_ok {
		log.infof("loaded renderdoc %v", rdoc_api)
	}

	rdoc_api.SetCaptureFilePathTemplate("captures/capture.rdc")

	// if you want to disable default behaviour of renderdoc capture keys
	// rdoc_api.SetCaptureKeys(nil, 0)
	
	if !glfw.Init() {
		return
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 5)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	window_handle: glfw.WindowHandle = glfw.CreateWindow(640, 480, "basic window", nil, nil)
	if (window_handle == nil) {
		glfw.Terminate()
		return
	}
	
	glfw.MakeContextCurrent(window_handle)
	gl.load_up_to(4, 5, glfw.gl_set_proc_address);

	glfw.SwapInterval(1)
	glfw.SetKeyCallback(window_handle, KeyCallback)

	gl.ClearColor(0.1, 0.1, 0.1, 1.0)

	vao, vbo, ibo: u32

	vertices: []f32 = {
		0.0,  0.5,  0.0,
		0.5, -0.5,  0.0,
	   -0.5, -0.5,  0.0,
	}

	indices: []u32 = {0, 1, 2}

	gl.GenVertexArrays(1, &vao)
	gl.BindVertexArray(vao)

	gl.GenBuffers(1, &vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo)
	gl.BufferData(gl.ARRAY_BUFFER, 3 * len(vertices) * size_of(f32), raw_data(vertices), gl.DYNAMIC_DRAW)

	gl.GenBuffers(1, &ibo)
	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, ibo)
	gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, len(indices) * size_of(u32), raw_data(indices), gl.DYNAMIC_DRAW)

	gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 3 * size_of(f32), 0)
	gl.EnableVertexAttribArray(0)

	vssource := `
		#version 450 core

		layout (location = 0) in vec3 aPos;
		
		out vec4 vertexColor;

		void main()
		{
			gl_Position = vec4(aPos, 1.0);
			vertexColor = vec4(0.5, 1.0, 0.0, 1.0);
		}
	`

	fssource := `
		#version 450 core
		
		in vec4 vertexColor;

		out vec4 FragColor;

		void main()
		{
			FragColor = vertexColor;
		}
	`

	program_id, ok := gl.load_shaders_source(vssource, fssource)

	gl.UseProgram(program_id)

	for !glfw.WindowShouldClose(window_handle) {
		
		// rendering scope for rdoc
		{
			// capture with StartFrameCapture/EndFrameCapture
			if rdoc_stage == .Capture {
				log.info("starting frame capture")
				rdoc_api.StartFrameCapture(nil, nil)
			}
			defer if rdoc_stage == .Capture {
				log.info("ending frame capture")
				rdoc_api.EndFrameCapture(nil, nil)
				rdoc_stage = .LaunchUI
			}

			// or capture with TriggerCapture
			if rdoc_stage == .Trigger {
				log.info("triggering frame capture")
				rdoc_api.TriggerCapture()
				rdoc_stage = .LaunchUI
			}
			if rdoc_stage == .TriggerMulti {
				// @TODO: triggerring multi captures as your first capture doesnt open the Renderdoc UI
				log.info("triggering 10 frame captures")
				rdoc_api.TriggerMultiFrameCapture(10)
				rdoc_stage = .LaunchUI
			}

			if rdoc_stage == .LaunchUI {
				if rdoc_api.IsFrameCapturing() == 0 {
					LaunchOrShowRenderdocUI(rdoc_api)
					rdoc_stage = .None
				} else {
					log.info("waiting for capture to complete")
				}
			}

			gl.Clear(gl.COLOR_BUFFER_BIT)
			
			gl.BindVertexArray(vao)
			gl.DrawElements(gl.TRIANGLES, cast(i32)len(indices), gl.UNSIGNED_INT, nil)
	
			glfw.SwapBuffers(window_handle)
		}

		glfw.PollEvents();
	}

	glfw.DestroyWindow(window_handle)
	glfw.Terminate()

	rdoc.unload_api(rdoc_lib)
	log.infof("unloaded renderdoc")
}