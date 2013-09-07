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

package de.flintfabrik.starling.events
{
    
	import starling.events.Event;
	 
    /** A VideoEvent is triggered once per video/camera frame and dispatched by Video/WebcamVideo.
     *
     *  They may come in handy if you want to handle the draw/upload process yourself; if you
	 *  want to process a BitmapData/ByteArrays only if it gets updated (AR); or if you want to
	 *  use a custom renderer for the video.
	 *  
	 *  @see de.flintfabrik.starling.display.Video
	 *  @see de.flintfabrik.starling.display.WebcamVideo
	 * 
     */ 
	public class VideoEvent extends starling.events.Event
    {
        /** Event type for a new frame available. */
		public static const VIDEO_FRAME:String = "videoFrame";
		/** Event type for a new frame drawn to BitmapData/ByteArray. */
		public static const DRAW_COMPLETE:String = "drawComplete";
		/** Event type for a new frame uploaded to the Texture. */
		public static const UPLOAD_COMPLETE:String = "uploadComplete";
		
        /* Creates an enter frame event with the passed time. */
        public function VideoEvent(type:String, bubbles:Boolean=false, data:Object=null)
        {
            super(type, bubbles, data);
        }
        
    }
}