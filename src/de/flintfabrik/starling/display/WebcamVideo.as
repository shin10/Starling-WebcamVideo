/**
 *	Copyright (c) 2013 Michael Trenkler
 *
 *	Permission is hereby granted, free of charge, to any person obtaining a copy
 *	of this software and associated documentation files (the "Software"), to deal
 *	in the Software without restriction, including without limitation the rights
 *	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 *	copies of the Software, and to permit persons to whom the Software is
 *	furnished to do so, subject to the following conditions:
 *
 *	The above copyright notice and this permission notice shall be included in
 *	all copies or substantial portions of the Software.
 *
 *	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 *	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 *	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 *	THE SOFTWARE.
 */

package de.flintfabrik.starling.display
{
	import de.flintfabrik.starling.events.VideoEvent;
	import flash.desktop.*;
	import flash.display.BitmapData;
	import flash.display3D.Context3D;
	import flash.display3D.Context3DProfile;
	import flash.display3D.textures.*;
	import flash.events.Event;
	import flash.events.StatusEvent;
	import flash.geom.Matrix;
	import flash.geom.Rectangle;
	import flash.media.Camera;
	import flash.media.Video;
	import flash.system.Capabilities;
	import flash.utils.ByteArray;
	import flash.utils.Endian;
	import flash.utils.getDefinitionByName;
	import flash.utils.getQualifiedClassName;
	import flash.utils.getTimer;
	import starling.core.RenderSupport;
	import starling.core.Starling;
	import starling.display.BlendMode;
	import starling.display.Quad;
	import starling.errors.MissingContextError;
	import starling.events.Event;
	import starling.textures.ConcreteTexture;
	import starling.textures.Texture;
	import starling.textures.TextureSmoothing;
	import starling.utils.getNextPowerOfTwo;
	import starling.utils.VertexData;
	
	
	
	/** Dispatched when a new frame of the camera is available. */
    [Event(name="videoFrame", type="de.flintfabrik.starling.events.VideoEvent")]
    /** Dispatched after a new frame has been drawn to BitmapData/ByteArray. */
    [Event(name="drawComplete", type="de.flintfabrik.starling.events.VideoEvent")]
    /** Dispatched after a new frame has been uploaded from the BitmapData/ByteArray to texture. */
    [Event(name="uploadComplete", type="de.flintfabrik.starling.events.VideoEvent")]
    
	
	/** A WebcamVideo is a Quad with a texture mapped onto it.
	 *
	 *  <p>The WebcamVideo class is more or less a Starling equivalent of Flash's Video class with attached Camera.
	 *  The texture is written automatically if not specified otherwise. Never the less you can use other DisplayObjects
	 *  for rendering as well and or handle the drawing and uploading yourself if you want to.</p>
	 *
	 *  <p>As "WebcamVideo" inherits from "Quad", you can give it a color. For each pixel, the resulting
	 *  color will be the result of the multiplication of the color of the texture with the color of
	 *  the quad. That way, you can easily tint textures with a certain color. Furthermore flipping is simply done by
	 *  adjusting the vertexData.</p>
	 *
	 *  <p>Uploading textures to the GPU is very expensive. This may be no problem on desktop computers
	 *  but it is a big problem on most mobile devices. Therefore it is very important to chose the right
	 *  resolution and texture size, as well as the method for drawing and uploading.
	 *  If you use Flash 11.8 / AIR 3.8 (-swf-version=21) RectangleTextures are supported if necessary. Versions below will
	 *  always fall back to Textue, so make sure to use the cropping rect parameter to avoid the upload of unused bytes.</p>
	 *
	 *  <p><strong>Note:</strong> <em>Unfortunatelly you may have to use a strategy with DRAW_BITMAPDATA or UPLOAD_FROM_BYTEARRAY
	 *  to keep the image centered, using the cropping rect if you use a regular POT Texture (FP 11.7/ AIR 3.7
	 *  and below), since camera.drawToBitmapData() does not support a rect parameter.</em>
	 *  See examples below and read more about performance of POT/NPOT Textures here:
	 *  <ul>
	 *  <li><a href="http://www.flintfabrik.de/blog/camera-performance-with-stage3d">Webcam Performance with Stage3D – Part I (desktop/mobile)</a></li>
	 *  <li><a href="http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-ii-rectangletextures-in-air-3-8-beta">Webcam Performance with Stage3D – Part II RectangleTextures in AIR 3.8 Beta (desktop)</a></li>
	 *  <li><a href="http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-iii-rectangletextures-in-air-3-8-beta-mobile">Webcam Performance with Stage3D – Part III RectangleTextures in AIR 3.8 Beta (mobile)</a></li>
	 *  </ul>
	 *  </p>
	 *
	 *  @see starling.textures.Texture
	 *  @see starling.display.Quad
	 *
	 *  @see http://www.flintfabrik.de/blog/camera-performance-with-stage3d
	 *  @author Michael Trenkler
	 */
	
	public class WebcamVideo extends starling.display.Quad
	{
		
		public static const DRAW_BITMAPDATA:int = 0;
		public static const DRAW_CAMERA:int = BIT_DRAW;
		public static const ALPHA:int = BIT_ALPHA;
		public static const OPAQUE:int = 0;
		public static const UPLOAD_FROM_BITMAPDATA:int = 0;
		public static const UPLOAD_FROM_BYTEARRAY:int = BIT_UPLOAD;
		
		private static const BIT_DRAW:int = 1;
		private static const BIT_ALPHA:int = 2;
		private static const BIT_UPLOAD:int = 4;
		
		public static var statsPrecision:uint = 15;
		
		private var mCamera:Camera = new Camera();
		private var mBitmapData:BitmapData;
		private var mByteArray:ByteArray;
		private var mFrame:Rectangle = new Rectangle();
		private var mFrameMatrix:Matrix = new Matrix();
		private var mVideo:flash.media.Video = new flash.media.Video();
		private var mTexture:ConcreteTexture;
		private var mActive:Boolean = true;
		private var mAddedToStage:Boolean = false;
		private var mAutoStartAfterHandledLostContext:Boolean = false;
		private var mContextLost:Boolean = false;
		private var mFlipHorizontal:Boolean = false;
		private var mFlipVertical:Boolean = false;
		private var mForceRecording:Boolean = false;
		private var mNewFrameAvailable:Boolean = false;
		private var mRecording:Boolean = true;
		private var mSmoothing:String = TextureSmoothing.TRILINEAR;
		private var mStrategy:int = 0;
		private var mTextureClass:Class;
		private var mNativeApplicationClass:Class;
		private var mTime:uint;
		private var mStatsDrawTime:Vector.<uint> = new Vector.<uint>();
		private var mStatsUploadTime:Vector.<uint> = new Vector.<uint>();
		private var mStatsDrawnFrames:uint = 0;
		private var mStatsUploadedFrames:uint = 0;
		private var mVertexDataCache:VertexData;
		private var mVertexDataCacheInvalid:Boolean;
		
		/** Creates a WebcamVideo
		 * @param camera
		 * The Camera attached to the WebcamVideo
		 * @param rect
		 * A cropping rectangle. If null, the full image will be drawn.
		 * @param autoStart
		 * If true the camera will be drawn to texture as soon as the WebcamVideo instance is added to stage.
		 * Recording stops automatically if the WebcamVideo instance is removed from stage. To prevent this
		 * behaviour use start(true) to force recording, even if the WebcamVideo is not part of the display list.
		 * @param strategy
		 * The draw/upload strategy.
		 * ALPHA/OPAQUE sets the alpha property of the used BitmapData.
		 * UPLOAD_FROM_BITMAPDATA/UPLOAD_FROM_BYTEARRAY will set the Texture.uploadFromBitmapData/Texture.uploadFromByteArray
		 * function for uploading
		 * DRAW_CAMERA uses camera.drawToBitmapData / camera.copyToByteArray to capture the video
		 * DRAW_BITMAPDATA will use the bitmapData.draw(video) method (and bitmapData.copyToByteArray if necessary)
		 * @default	WebcamVideo.DRAW_CAMERA + WebcamVideo.OPAQUE + WebcamVideo.UPLOAD_FROM_BITMAPDATA
		 * 
		 * @example The following code shows a simple usage in Flash 11.8 / AIR 3.8 and above:
		 * <listing version="3.8">
package
{
	import de.flintfabrik.starling.display.WebcamVideo;
	import de.flintfabrik.starling.events.VideoEvent;
	
	import flash.geom.Rectangle;
	import flash.media.CameraPosition;
	import flash.media.Camera;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import starling.core.Starling;
	import starling.display.Sprite;
	import starling.textures.Texture;
	import starling.text.TextField;
	
	public class WebcamTest extends Sprite
	{
		
		private var webcamVideo:WebcamVideo;
		private var statsTextField:TextField;
		private var statsTimer:Timer = new Timer(1000, 0);
		private var camera:Camera;
		
		public function WebcamTest()
		{
		
			camera = Camera.getCamera();
			camera.setLoopback(false);
			camera.setMode(1280, 720, 15);
		
			webcamVideo = new WebcamVideo(camera);
			center(webcamVideo);
			addChild(webcamVideo);
		
			statsTextField = new TextField(200, 100, &quot;CAMERA DEBUG&quot;, &quot;Arial&quot;, 10, 0xFF00FF, true);
			statsTextField.hAlign = &quot;left&quot;;
			statsTextField.vAlign = &quot;top&quot;;
			statsTextField.y = 26;
			addChild(statsTextField);
		
			statsTimer.addEventListener(TimerEvent.TIMER, statsTimer_timerHandler);
			statsTimer.start();
			
		}
		
		private function center(wv:WebcamVideo):void
		{
			wv.height = Starling.current.stage.stageHeight;
			wv.scaleX = wv.scaleY;
			wv.x = (Starling.current.stage.stageWidth - wv.width) ~~ .5;
			wv.y = (Starling.current.stage.stageHeight - wv.height) ~~ .5;
			wv.flipHorizontal = wv.camera.position != CameraPosition.BACK;
		}
		
		
		private function statsTimer_timerHandler(e:TimerEvent):void {
			statsTextField.text = &quot;FPS:\t&quot; + camera.currentFPS.toFixed(1) + &quot;/&quot; + camera.fps.toFixed(1)
			+ &quot;\ncam:\t&quot; + camera.width + &quot;x&quot; + camera.height
			+ &quot;\ntextureClass: &quot; + webcamVideo.texture.root.base
			+ &quot;\ntexture:\t&quot; + webcamVideo.texture.root.nativeWidth + &quot;x&quot; +  webcamVideo.texture.root.nativeHeight
			+ &quot;\ndraw:\t&quot; + webcamVideo.drawTime.toFixed(2) + &quot; ms&quot;
			+ &quot;\nupload:\t&quot; + webcamVideo.uploadTime.toFixed(2) + &quot; ms&quot;
			+ &quot;\ncomplete:\t&quot; + (webcamVideo.drawTime+webcamVideo.uploadTime).toFixed(2)+&quot; ms&quot;;
		}
	}
}
		 * </listing>
		 *
		 * @example In versions Flash 11.7 / AIR 3.7 and below make sure to use a clipping Rect and adjust the strategy, e.g. like this:
		 * <listing>
camera.setMode(640, 640, 15);
var cropping:Rectangle = new Rectangle(0, 0, getLowerPowerOfTwo(camera.width), getLowerPowerOfTwo(camera.height));
webcamVideo = new WebcamVideo(camera, new Rectangle( (camera.width-cropping.width)~~.5, (camera.height-cropping.height)~~.5, cropping.width, cropping.height), true, WebcamVideo.DRAW_BITMAPDATA|WebcamVideo.UPLOAD_FROM_BITMAPDATA);
		 * </listing>
		 *
		 * @example Full example (Flash 11.7 / AIR 3.7 and below):
		 * <listing>
package {
	import de.flintfabrik.starling.display.WebcamVideo;
	import de.flintfabrik.starling.events.VideoEvent;
	
	import flash.geom.Rectangle;
	import flash.media.CameraPosition;
	import flash.media.Camera;
	import flash.events.TimerEvent;
	import flash.utils.Timer;
	
	import starling.core.Starling;
	import starling.display.Sprite;
	import starling.textures.Texture;
	import starling.text.TextField;
	
	public class WebcamTest extends Sprite {
		
		private var webcamVideo:WebcamVideo;
		private var statsTextField:TextField;
		private var statsTimer:Timer = new Timer(1000, 0);
		private var camera:Camera;
		
		public function WebcamTest() {
			
			camera = Camera.getCamera();
			camera.setLoopback(false);
			camera.setMode(640, 640, 15);
			var cropping:Rectangle = new Rectangle(0, 0, getLowerPowerOfTwo(camera.width), getLowerPowerOfTwo(camera.height));
			webcamVideo = new WebcamVideo(camera, new Rectangle( (camera.width-cropping.width)~~.5, (camera.height-cropping.height)~~.5, cropping.width, cropping.height), true, WebcamVideo.DRAW_BITMAPDATA|WebcamVideo.UPLOAD_FROM_BITMAPDATA);
			center(webcamVideo);
			addChild(webcamVideo);
			
			statsTextField = new TextField(200, 100, &quot;CAMERA DEBUG&quot;, &quot;Arial&quot;, 10,  0xFF00FF, true);
			statsTextField.hAlign = &quot;left&quot;;
			statsTextField.vAlign = &quot;top&quot;;
			statsTextField.y = 26;
			addChild(statsTextField);
			
			statsTimer.addEventListener(TimerEvent.TIMER, statsTimer_timerHandler);
			statsTimer.start();
		
		}
		private function getLowerPowerOfTwo(val:int):int {
			var result:int = 1;
			val &gt;&gt;= 1;
			while (val) {
			val &gt;&gt;= 1;
			result &lt;&lt;= 1;
			}
			return result;
		}
		
		private function center(wv:WebcamVideo):void {
			wv.height = Starling.current.stage.stageHeight;
			wv.scaleX = wv.scaleY;
			wv.x = (Starling.current.stage.stageWidth - wv.width) ~~ .5;
			wv.y = (Starling.current.stage.stageHeight - wv.height) ~~ .5;
			wv.flipHorizontal = wv.camera.position != CameraPosition.BACK;
		}
		
		private function statsTimer_timerHandler(e:TimerEvent):void {
			statsTextField.text = &quot;FPS:\t&quot; + camera.currentFPS.toFixed(1) + &quot;/&quot; + camera.fps.toFixed(1)
			+ &quot;\ncam:\t&quot; + camera.width + &quot;x&quot; + camera.height
			+ &quot;\ntextureClass: &quot; + webcamVideo.texture.root.base
			+ &quot;\ntexture:\t&quot; + webcamVideo.texture.root.nativeWidth + &quot;x&quot; +  webcamVideo.texture.root.nativeHeight
			+ &quot;\ndraw:\t&quot; + webcamVideo.drawTime.toFixed(2) + &quot; ms&quot;
			+ &quot;\nupload:\t&quot; + webcamVideo.uploadTime.toFixed(2) + &quot; ms&quot;
			+ &quot;\ncomplete:\t&quot; + (webcamVideo.drawTime+webcamVideo.uploadTime).toFixed(2)+&quot; ms&quot;;
		}
	}
}
		 * </listing>
		 */
		
		public function WebcamVideo(camera:Camera, rect:Rectangle = null, autoStart:Boolean = true, strategy:uint = 0) {
			var pma:Boolean = true;
			mCamera = camera;
			if (rect == null)
				rect = new Rectangle(0, 0, mCamera.width, mCamera.height);
			mFrame = new Rectangle(rect.x, rect.y, Math.min(mCamera.width - rect.x, rect.width), Math.min(mCamera.height - rect.y, rect.height));
			super(mFrame.width, mFrame.height, 0xffffff, pma);
			
			mRecording = autoStart;
			if (strategy > BIT_DRAW + BIT_ALPHA + BIT_UPLOAD)
				throw new ArgumentError("Invalid strategy");
			mStrategy = strategy;
			
			readjustSize(mFrame);
			mVertexDataCache = new VertexData(4, pma);
			updateVertexData();
			
			if (Camera.isSupported)
			{
				if (mCamera.width == -1)
				{
					throw new Error("Camera is supported but camera.width=-1\nTip: This can happen if you haven't set the desriptor argument in application.xml.");
					return;
				}
			}
			else
			{
				throw new Error("Camera is not supported.");
			}
			
			addEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
			
			// Android / iOS / Blackberry?
			if(Capabilities.playerType.match(/desktop/i)){
				try{
					mNativeApplicationClass = Class(getDefinitionByName("flash.desktop.NativeApplication"));
					if((Capabilities.os+Capabilities.manufacturer).match(/Android|iOS|iPhone|iPad|iPod|Blackberry/i) && mNativeApplicationClass && mNativeApplicationClass.nativeApplication) {
						mNativeApplicationClass.nativeApplication.addEventListener(flash.events.Event.ACTIVATE, activateHandler);
						mNativeApplicationClass.nativeApplication.addEventListener(flash.events.Event.DEACTIVATE, deactivateHandler);
					}
				}catch (err:*) {
					trace(err.toString())
				}
			}
			// windows and web
			Starling.current.addEventListener(starling.events.Event.CONTEXT3D_CREATE, contextCreateHandler);
			
		}
		
		/**
		 * Resume on application focus for mobile devices.
		 * @param	e
		 */
		private function activateHandler(e:flash.events.Event):void 
		{
			mCamera.setMode(mCamera.width, mCamera.height, mCamera.fps);
			start(mAutoStartAfterHandledLostContext);
		}
		
		/**
		 * Starting the camera if the instance is added to the stage and autoStart true.
		 * @param	e
		 */
		private function addedToStageHandler(e:starling.events.Event):void
		{
			mAddedToStage = true;
			onCameraChange();
			mCamera.addEventListener(StatusEvent.STATUS, camera_statusHandler, false, 0, true);
			addEventListener(starling.events.Event.REMOVED_FROM_STAGE, removedFromStageHandler);
		}
		
		/**
		 * Stops the camera if the instance is removed from the stage and autoStart true.
		 * @param	e
		 */
		private function camera_statusHandler(e:StatusEvent):void
		{
			onCameraChange();
		}
		
		/**
		 * Is called when a new frame is available.
		 * @param	e
		 */
		private function camera_videoFrameHandler(e:flash.events.Event):void
		{
			if (!contextStatus)
				return;
			
			mNewFrameAvailable = true;
			dispatchEventWith(VideoEvent.VIDEO_FRAME);
			if (mRecording)
			{
				draw();
				upload();
			}
		}
		
		/**
		 * Restart after device loss.
		 * @param	e
		 */
		private function contextCreateHandler(e:starling.events.Event):void
		{
			if (Starling.current.context && Starling.current.context.driverInfo != "Disposed" && mContextLost)
			{
				mContextLost = false;
				mCamera.setMode(mCamera.width, mCamera.height, mCamera.fps);
				readjustSize(mFrame);
				start(mAutoStartAfterHandledLostContext);
			}
		}
		
		/** Copies the raw vertex data to a VertexData instance.
		 *  The texture coordinates are already in the format required for rendering. */
		public override function copyVertexDataTo(targetData:VertexData, targetVertexID:int = 0):void
		{
			if (mVertexDataCacheInvalid)
			{
				mVertexDataCacheInvalid = false;
				mVertexData.copyTo(mVertexDataCache);
				mTexture.adjustVertexData(mVertexDataCache, 0, 4);
			}
			
			mVertexDataCache.copyTo(targetData, targetVertexID);
		}
		
		/**
		 * Pause on lost application focus for mobile devices.
		 * @param	e
		 */
		private function deactivateHandler(e:flash.events.Event):void 
		{
			mAutoStartAfterHandledLostContext = isActive;
			pause();
		}
		
		/** Disposes all resources of the WebcamVideo Object.
		 *  Detaches the camera, removes EventListeners, disposes textures and bitmapDatas.
		 */
		override public function dispose():void
		{
			removeEventListener(starling.events.Event.ADDED_TO_STAGE, addedToStageHandler);
			removeEventListener(starling.events.Event.REMOVED_FROM_STAGE, removedFromStageHandler);
			mCamera.removeEventListener(StatusEvent.STATUS, camera_statusHandler);
			mCamera.removeEventListener(flash.events.Event.VIDEO_FRAME, camera_videoFrameHandler);
			Starling.current.removeEventListener(starling.events.Event.CONTEXT3D_CREATE, contextCreateHandler);
			if(mNativeApplicationClass){
				mNativeApplicationClass.nativeApplication.removeEventListener(flash.events.Event.ACTIVATE, activateHandler);
				mNativeApplicationClass.nativeApplication.removeEventListener(flash.events.Event.DEACTIVATE, deactivateHandler);
			}
			if (mVideo)
				mVideo.attachCamera(null);
			if (mTexture)
				mTexture.dispose();
			if (texture)
				texture.dispose();
			if (mBitmapData)
				mBitmapData.dispose();
			if (mByteArray)
				mByteArray.clear();
			if (parent)
				parent.removeChild(this);
			super.dispose();
		}
		
		/**
		 * Drawing the camera image to the BitmapData/ByteArray, according to the chosen strategy.
		 * @see WebcamVideo
		 */
		public function draw():void
		{
			if (!contextStatus)
				return;
				
			mTime = getTimer();
			if ((mStrategy & BIT_UPLOAD) == UPLOAD_FROM_BITMAPDATA)
			{
				if ((mStrategy & BIT_DRAW) == DRAW_BITMAPDATA)
				{
					mBitmapData.draw(mVideo, mFrameMatrix);
				}
				else
				{
					mCamera.drawToBitmapData(mBitmapData);
				}
			}
			else
			{
				mByteArray.position = 0;
				if ((mStrategy & BIT_DRAW) == DRAW_BITMAPDATA)
				{
					mBitmapData.draw(mVideo, mFrameMatrix);
					mBitmapData.copyPixelsToByteArray(mBitmapData.rect, mByteArray);
				}
				else
				{
					mCamera.copyToByteArray(mFrame, mByteArray);
				}
			}
			mStatsDrawTime.unshift(getTimer() - mTime);
			while (mStatsDrawTime.length > statsPrecision)
				mStatsDrawTime.pop();
			mNewFrameAvailable = false;
			++mStatsDrawnFrames;
			dispatchEventWith(VideoEvent.DRAW_COMPLETE);
		}
		
		/** Adds or removes the EventListeners for drawing the texture. */
		private function onCameraChange():void
		{
			if (!mTexture)
				readjustSize();
			if (mActive && !mCamera.muted && (mAddedToStage || mForceRecording))
			{
				mVideo.attachCamera(mCamera);
				mCamera.addEventListener(flash.events.Event.VIDEO_FRAME, camera_videoFrameHandler, false, 0, true);
			}
			else
			{
				mCamera.removeEventListener(flash.events.Event.VIDEO_FRAME, camera_videoFrameHandler);
			}
		}
		
		/** @inheritDoc */
		protected override function onVertexDataChanged():void
		{
			mVertexDataCacheInvalid = true;
		}
		
		/** Pauses the Video EventListeners (drawing/uploading) but the camera will stay active.
		 *  @see start()
		 *  @see stop()
		 */
		public function pause():void
		{
			mRecording = false;
			onCameraChange();
		}
		
		/** Readjusts the dimensions of the video according to the current camera/croppingFrame. Call this method to synchronize
		 *  video and texture size after assigning another resolution with camera.setMode().
		 *  Further it resets drawnFrames, uploadedFrames as well as drawTime and uploadTime values.
		 *  This method is also called on start(), stop(), pause()
		 */
		public function readjustSize(rectangle:Rectangle = null):void
		{
			if (!contextStatus) return;
			mStatsDrawnFrames = 0;
			mStatsUploadedFrames = 0;
			mStatsDrawTime = new Vector.<uint>();
			mStatsUploadTime = new Vector.<uint>();
			
			if (rectangle == null)
				rectangle = new Rectangle(0, 0, mCamera.width, mCamera.height);
			mFrame = new Rectangle(rectangle.x, rectangle.y, Math.min(mCamera.width - rectangle.x, rectangle.width), Math.min(mCamera.height - rectangle.y, rectangle.height));
			
			if (mBitmapData)
				mBitmapData.dispose();
			if (mByteArray)
				mByteArray.clear();
			if (mTexture)
				mTexture.dispose();
			
			mVideo = new flash.media.Video(mCamera.width, mCamera.height);
			if (mRecording)
				mVideo.attachCamera(mCamera);
			mVideo.width = mCamera.width;
			mVideo.height = mCamera.height;
			
			if ((mStrategy & BIT_UPLOAD) == UPLOAD_FROM_BYTEARRAY)
			{
				//UPLOAD_FROM_BYTEARRAY
				mByteArray = new ByteArray();
				mByteArray.endian = Endian.LITTLE_ENDIAN;
				mByteArray.length = mFrame.width * mFrame.height * 4;
			}
			mFrameMatrix = new Matrix(1, 0, 0, 1, -mFrame.x, -mFrame.y);
			
			var w:int = mFrame.width;
			var h:int = mFrame.height;
			var potWidth:int   = getNextPowerOfTwo(w);
            var potHeight:int  = getNextPowerOfTwo(h);
            var isPot:Boolean  = (w == potWidth && h == potHeight);
            var useRectTexture:Boolean = Starling.current.profile != Context3DProfile.BASELINE_CONSTRAINED &&
                "createRectangleTexture" in Starling.context;
			if (!useRectTexture) {
				w = potWidth;
				h = potHeight;
			}
			mBitmapData = new BitmapData(w, h, (mStrategy & BIT_ALPHA) == ALPHA, 0);
			mBitmapData.lock();
			_texture = starling.textures.Texture.fromBitmapData(mBitmapData, false) as ConcreteTexture;
			if ((mStrategy & BIT_DRAW) == DRAW_BITMAPDATA || (mStrategy & BIT_UPLOAD) == UPLOAD_FROM_BITMAPDATA){
				//keep bitmapData
			}else {
				mBitmapData.dispose();
				mBitmapData = null;
			}
			
			if (!mVertexData)
				return;
			mVertexData.setPosition(0, 0.0, 0.0);
			mVertexData.setPosition(1, mFrame.width, 0.0);
			mVertexData.setPosition(2, 0.0, mFrame.height);
			mVertexData.setPosition(3, mFrame.width, mFrame.height);
			onVertexDataChanged();
			
			// if you're using an older version of Starling and get a compile time error, replace the line above with:
			// _texture = starling.textures.Texture.empty(mFrame.width, mFrame.height, true, false, -1);
		}
		
		/**
		 * Stops the camera if the instance is removed from the stage and autoStart true.
		 * @param	e
		 */
		private function removedFromStageHandler(e:starling.events.Event):void
		{
			mCamera.removeEventListener(flash.events.Event.VIDEO_FRAME, camera_videoFrameHandler);
			mAddedToStage = false;
		}
		
		/** @inheritDoc */
		public override function render(support:RenderSupport, parentAlpha:Number):void
		{
			if(mTexture) support.batchQuad(this, parentAlpha, mTexture, mSmoothing);
		}
		
		/**
		 * Starting/Resuming the camera.
		 * @param	forceRecording
		 * Starts the camera even if the WebcamVideo has not been added to stage. E.g. to use the texture
		 * in multiple Images, a ParticleSystem, with a custom renderer or whatever, instead of the WebcamVideo itself.
		 *  @see pause()
		 *  @see stop()
		 */
		public function start(forceRecording:Boolean = false):void
		{
			mActive = true;
			mRecording = true;
			mForceRecording = forceRecording;
			onCameraChange();
		}
		
		/** Stopping the camera and EventListeners.
		 *  @see pause()
		 *  @see start()
		 */
		public function stop():void
		{
			mActive = false;
			pause();
			if (mVideo)
				mVideo.attachCamera(null);
		}
		
		/**
		 * Updates vertexData if flipped horizontally/vertically.
		 */
		private function updateVertexData():void
		{
			mVertexData.setTexCoords(0, mFlipHorizontal ? 1.0 : 0.0, mFlipVertical ? 1.0 : 0.0);
			mVertexData.setTexCoords(1, mFlipHorizontal ? 0.0 : 1.0, mFlipVertical ? 1.0 : 0.0);
			mVertexData.setTexCoords(2, mFlipHorizontal ? 1.0 : 0.0, mFlipVertical ? 0.0 : 1.0);
			mVertexData.setTexCoords(3, mFlipHorizontal ? 0.0 : 1.0, mFlipVertical ? 0.0 : 1.0);
			mVertexDataCacheInvalid = true;
		}
		
		/**
		 * Uploading the BitmapData/ByteArray, according to the chosen strategy.
		 * @see WebcamVideo
		 */
		public function upload():void
		{
			if (!contextStatus)
				return;
			
			mTime = getTimer();
			if ((mStrategy & BIT_UPLOAD) == UPLOAD_FROM_BITMAPDATA)
			{
				mTextureClass(mTexture.base).uploadFromBitmapData(mBitmapData);
			}
			else
			{
				mTextureClass(mTexture.base).uploadFromByteArray(mByteArray, 0);
			}
			mStatsUploadTime.unshift(getTimer() - mTime);
			while (mStatsUploadTime.length > statsPrecision)
				mStatsUploadTime.pop();
			++mStatsUploadedFrames;
			dispatchEventWith(VideoEvent.UPLOAD_COMPLETE);
		}
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		
		/**
		 * The bitmapData with the camera image (if in use), for example to calculate stuff in a game or augmented reality application.
		 * Do NOT change the reference or call dispose() on it!
		 */
		public function get bitmapData():BitmapData
		{
			return mBitmapData;
		}
		
		/**
		 * The byteArray with the camera image (if in use), for example to calculate stuff in a game or augmented reality application.
		 * Do NOT change the reference or call clear() on it!
		 */
		public function get byteArray():ByteArray
		{
			return mByteArray;
		}
		
		/**
		 * Returns the camera object. You may change the resolution with setMode() but you'll have to call readjustSize() afterwards to
		 * update the texture size and cropping.
		 * @see readjustSize()
		 */
		public function get camera():Camera
		{
			return mCamera;
		}
		
		/**
		 * Returns a Boolean whether the context is available or not (e.g. disposed)
		 * @return
		 */
		private function get contextStatus():Boolean
		{
			if (!Starling.current.context || Starling.current.context.driverInfo == "Disposed")
			{
				mContextLost = true;
				mNewFrameAvailable = false;
				mAutoStartAfterHandledLostContext = isActive;
				pause();
				return false;
			}
			else if (Starling.current.context && Starling.current.context.driverInfo != "Disposed" && mContextLost)
			{
				mCamera.setMode(mCamera.width, mCamera.height, mCamera.fps);
				mContextLost = false;
				return false;
			}
			return true;
		}
		
		/**
		 * Returns the number of drawn frames since the last call of start(), stop(), pause() or readjustSize()
		 */
		public function get drawnFrames():uint
		{
			return mStatsDrawnFrames;
		}
		
		/**
		 * Returns the average drawing time (up to 15 frames, if already available)
		 */
		public function get drawTime():Number
		{
			var res:Number = 0;
			var len:uint = mStatsDrawTime.length;
			for (var i:int = len - 1; i >= 0; --i)
			{
				res += mStatsDrawTime[i];
			}
			return res / len;
		}
		
		/**
		 * Returns whether the vertexData of the WebcamVideo instance is flipped horizontally.
		 */
		public function get flipHorizontal():Boolean
		{
			return mFlipHorizontal;
		}
		
		/**
		 * Mirrors the video horizontally. This just changes the vertexData, neither bitmapData nor texture.
		 */
		public function set flipHorizontal(value:Boolean):void
		{
			mFlipHorizontal = value;
			updateVertexData();
		}
		
		/**
		 * Returns whether the vertexData of the WebcamVideo instance is flipped vertically.
		 */
		public function get flipVertical():Boolean
		{
			return mFlipVertical;
		}
		
		/**
		 * Mirrors the video vertically. This just changes the vertexData, neither bitmapData nor texture.
		 */
		public function set flipVertical(value:Boolean):void
		{
			mFlipVertical = value;
			updateVertexData();
		}
		
		/** Returns whether the camera is drawn and uploaded to texture or not.
		 *  Note: If the camera is not on stage it will never be drawn to texturere regardless of it's active state.
		 *  Nevertheless it will start as soon as it is added to the stage if active is true.
		 *  @see start()
		 */
		public function get isRecording():Boolean
		{
			return mRecording || mForceRecording;
		}
		
		/** Returns whether the camera is active.
		 *  Note: The camera being active doesn't mean that it is recording. If you want to know whether the camera
		 *  will be drawn and uploaded, use isRecording instead.
		 *  @see start()
		 */
		public function get isActive():Boolean
		{
			return mActive;
		}
		
		/**
		 * Returns whether a new webcam frame is available but hasn't been drawn, yet.
		 */
		public function get newFrameAvailable():Boolean
		{
			return mNewFrameAvailable;
		}
		
		/** The smoothing filter that is used for rendering the texture.
		 *   @default NONE
		 *   @see starling.textures.TextureSmoothing
		 */
		public function get smoothing():String
		{
			return mSmoothing;
		}
		
		public function set smoothing(value:String):void
		{
			if (TextureSmoothing.isValid(value))
				mSmoothing = value;
			else
				throw new ArgumentError("Invalid smoothing mode: " + value);
		}
		
		/** The texture with the camera image. Can be used in other DisplayObjects then the WebcamVideo as well.
		 *  Note: The texture will never be transformed by the use of flipHorizontal/flipVertical.
		 */
		public function get texture():ConcreteTexture
		{
			return mTexture;
		}
		
		private function set _texture(value:ConcreteTexture):void
		{
			if (value == null)
			{
				throw new ArgumentError("Texture cannot be null");
			}
			else if (value != mTexture)
			{
				if (mTexture) mTexture.dispose();
				mTexture = value;
				mTextureClass = Class(getDefinitionByName(getQualifiedClassName(mTexture.base)));
				if(mTexture["onRestore"])mTexture["onRestore"] = null;
				mVertexData.setPremultipliedAlpha(mTexture.premultipliedAlpha);
				onVertexDataChanged();
			}
		}
		
		/**
		 * Returns the number of uploaded frames since the last call of start(), stop(), pause() or readjustSize()
		 */
		public function get uploadedFrames():uint
		{
			return mStatsUploadedFrames;
		}
		
		/**
		 * Returns the average upload time (up to 15 frames, if already available)
		 */
		public function get uploadTime():Number
		{
			var res:Number = 0;
			var len:uint = mStatsUploadTime.length;
			for (var i:int = len - 1; i >= 0; --i)
			{
				res += mStatsUploadTime[i];
			}
			return res / len;
		}
		
	}

}
