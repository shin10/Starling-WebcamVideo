package starling.extensions.events
{
    
	import starling.events.Event;
	 
    /** A WebcamVideoEvent is triggered once per camera frame and is dispatched by WebcamVideo.
     *
     *  They may come in handy if you want to handle the draw/upload process yourself; if you
	 *  want to process a BitmapData/ByteArrays only if it gets updated (AR); or if you want to
	 *  use a custom renderer for the video.
	 *  
	 *  @see starling.extensions.WebcamVideo
     */ 
	public class WebcamVideoEvent extends starling.events.Event
    {
        /** Event type for a new camera frame available. */
		public static const VIDEO_FRAME:String = "videoFrame";
		/** Event type for a new frame drawn to BitmapData/ByteArray. */
		public static const DRAW_COMPLETE:String = "drawComplete";
		/** Event type for a new frame uploaded to the Texture. */
		public static const UPLOAD_COMPLETE:String = "uploadComplete";
		
        /* Creates an enter frame event with the passed time. */
        public function WebcamVideoEvent(type:String, bubbles:Boolean=false, data:Object=null)
        {
            super(type, bubbles, data);
        }
        
    }
}