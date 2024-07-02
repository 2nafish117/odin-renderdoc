package main

import "core:log"
import "core:fmt"
import "base:runtime"
import "core:c"
import "vendor:glfw"
import "core:strings"
import gl "vendor:OpenGL"

import rdoc ".."

KeyCallback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mods: c.int) {
	// handle showing ui
	if key == glfw.KEY_F2 && action == glfw.PRESS {
		user := transmute(^GlfwUserData) glfw.GetWindowUserPointer(window)
		context = user.glfw_context
		rdoc_api := user.rdoc_api

		// @TODO: I want to be able to, press button to capture and load up renderdoc together
		// press capture button
		// capture next frame
		// open ui next frame after that
		if rdoc_api.IsFrameCapturing() == 0 && rdoc_api.IsTargetControlConnected() == 0 {
			latest_capture_index := rdoc_api.GetNumCaptures() - 1
			
			timestamp: u64
			capture_file: []u8
			capture_file_len: u32
	
			if rdoc_api.GetCapture(latest_capture_index, nil, &capture_file_len, &timestamp) != 0 {
				capture_file = make([]u8, capture_file_len + 1, context.temp_allocator)
				rdoc_api.GetCapture(latest_capture_index, transmute(cstring)raw_data(capture_file), nil, nil)
				log.infof("loading latest capture: %v", transmute(string)capture_file)
				pid := rdoc_api.LaunchReplayUI(1, transmute(cstring)raw_data(capture_file))
				if pid == 0 {
					log.error("couldnt launch Renderdoc UI")
				}
			}
			else {
				log.warnf("no valid capture exists to load")
			}
		}
	}
}

GlfwUserData :: struct {
	glfw_context: runtime.Context,
	rdoc_api: ^rdoc.RENDERDOC_API_1_6_0,
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

	window_handle: glfw.WindowHandle = glfw.CreateWindow(640/2, 480/2, "basic window", nil, nil)
	if (window_handle == nil) {
		glfw.Terminate()
		return
	}
	
	glfw.MakeContextCurrent(window_handle)
	gl.load_up_to(4, 5, glfw.gl_set_proc_address);

	glfw.SwapInterval(1)

	user_data := GlfwUserData {
		glfw_context = context,
		rdoc_api = rdoc_api,
	}
	glfw.SetWindowUserPointer(window_handle, &user_data)
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
		
		gl.Clear(gl.COLOR_BUFFER_BIT)
		
		gl.BindVertexArray(vao)
		gl.DrawElements(gl.TRIANGLES, cast(i32)len(indices), gl.UNSIGNED_INT, nil)

		glfw.SwapBuffers(window_handle)
		glfw.PollEvents();
	}

	glfw.DestroyWindow(window_handle)
	glfw.Terminate()

	rdoc.unload_api(rdoc_lib)
	log.infof("unloaded renderdoc")
}