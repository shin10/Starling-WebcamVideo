Starling-WebcamVideo
====================

An AS3 extension for the Starling framework - drawing/displaying webcam input.

A WebcamVideo is a Quad with a texture mapped onto it.
The WebcamVideo class is more or less a Starling equivalent of Flash's Video class with attached Camera. The texture is written automatically if not specified otherwise. Never the less you can use other DisplayObjects for rendering as well and or handle the drawing and uploading yourself if you want to.

As "WebcamVideo" inherits from "Quad", you can give it a color. For each pixel, the resulting color will be the result of the multiplication of the color of the texture with the color of the quad. That way, you can easily tint textures with a certain color. Furthermore flipping is simply done by adjusting the vertexData.

Uploading textures to the GPU is very expensive. This may be no problem on desktop computers but it is a big problem on most mobile devices. Therefore it is very important to chose the right resolution and texture size, as well as the method for drawing and uploading. If you use Flash 11.8 / AIR 3.8 (-swf-version=21) RectangleTextures are supported if necessary. Versions below will always fall back to Textue, so make sure to use the cropping rect parameter to avoid the upload of unused bytes.

Note: Unfortunatelly you may have to use a strategy with DRAW_BITMAPDATA or UPLOAD_FROM_BYTEARRAY to keep the image centered, using the cropping rect if you use a regular POT Texture (FP 11.7/ AIR 3.7 and below), since camera.drawToBitmapData() does not support a rect parameter. See examples in the documentation and read more about performance of POT/NPOT Textures here:

http://www.flintfabrik.de/blog/camera-performance-with-stage3d

http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-ii-rectangletextures-in-air-3-8-beta

http://www.flintfabrik.de/blog/webcam-performance-with-stage3d-part-iii-rectangletextures-in-air-3-8-beta-mobile
