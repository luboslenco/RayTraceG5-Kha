package;

import haxe.ds.Vector;
import kha.System;
import kha.Color;
import kha.Framebuffer;
import kha.Shaders;
import kha.graphics5.CommandList;
import kha.graphics5.RenderTarget;
import kha.graphics5.ConstantBuffer;
import kha.graphics5.RayTraceTarget;
import kha.graphics5.RayTracePipeline;
import kha.graphics5.AccelerationStructure;
import kha.graphics5.VertexBuffer;
import kha.graphics5.IndexBuffer;
import kha.graphics5.VertexStructure;
import kha.graphics5.VertexData;
import kha.graphics5.Usage;
import kha.graphics5.TextureFormat;

class Main {
	private static inline var bufferCount = 2;
	private static var currentBuffer = -1;
	private static var commandList: CommandList;
	private static var framebuffers = new Vector<RenderTarget>(bufferCount);
	private static var constantBuffer: ConstantBuffer;
	private static var target: RayTraceTarget;
	private static var pipeline: RayTracePipeline;
	private static var accel: AccelerationStructure;
	
	static function loadShaderBlobs(f: kha.Blob->Void) {
		kha.Assets.loadBlobFromPath("simple.cso", function(rayTraceShader: kha.Blob) {
			f(rayTraceShader);
		});
	}

	public static function main(): Void {
		System.start({title: "RayTrace", width: 1280, height: 720}, function (_) {
			loadShaderBlobs(function(rayTraceShader: kha.Blob) {

				// Command list
				commandList = new CommandList();
				for (i in 0...bufferCount) {
					framebuffers[i] = new RenderTarget(1280, 720, 16, false, TextureFormat.RGBA32,
					                                   -1, -i - 1 /* hack in an index for backbuffer render targets */);
				}
				commandList.end(); // TODO: Otherwise "Reset fails because the command list was not closed"

				// Pipeline
				constantBuffer = new ConstantBuffer(4 * 4);
				constantBuffer.lock();
				constantBuffer.setFloat(0, -1);
				constantBuffer.setFloat(4, -1);
				constantBuffer.setFloat(8, 1);
				constantBuffer.setFloat(12, 1);
				constantBuffer.unlock();

				pipeline = new RayTracePipeline(commandList, rayTraceShader, constantBuffer);

				// Acceleration structure
				var structure = new VertexStructure();
				structure.add("pos", VertexData.Float3);
				
				var vertices = new VertexBuffer(3, structure, Usage.StaticUsage);
				var v = vertices.lock();
				v[0] = 0.0; v[1] =-0.7; v[2] = 1.0;
				v[3] =-0.7; v[4] = 0.7; v[5] = 1.0;
				v[6] = 0.7; v[7] = 0.7; v[8] = 1.0;
				vertices.unlock();
				
				var indices = new IndexBuffer(3, Usage.StaticUsage);
				var i = indices.lock();
				i[0] = 0; i[1] = 1; i[2] = 2;
				indices.unlock();

				accel = new AccelerationStructure(commandList, vertices, indices);

				// Output
				target = new RayTraceTarget(1280, 720);
				
				System.notifyOnFrames(render);
			});
		});
	}
	
	private static function render(frames: Array<Framebuffer>): Void {
		var g = frames[0].g5;
		currentBuffer = (currentBuffer + 1) % bufferCount;

		g.begin(framebuffers[currentBuffer]);

		commandList.begin();
		g.setAccelerationStructure(accel);
		g.setRayTracePipeline(pipeline);
		g.setRayTraceTarget(target);
		g.dispatchRays(commandList);
		g.copyRayTraceTarget(commandList, framebuffers[currentBuffer], target);
		commandList.end();
		
		g.end();
		g.swapBuffers();
	}
}
