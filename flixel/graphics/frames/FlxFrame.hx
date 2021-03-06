package flixel.graphics.frames;

import flash.display.BitmapData;
import flash.geom.Matrix;
import flash.geom.Point;
import flash.geom.Rectangle;
import flixel.FlxG;
import flixel.graphics.frames.FlxFrame;
import flixel.math.FlxAngle;
import flixel.math.FlxRect;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.math.FlxMatrix;
import flixel.math.FlxPoint;
import flixel.graphics.FlxGraphic;
import flixel.util.FlxStringUtil;

/**
 * Base class for all frame types
 */
class FlxFrame implements IFlxDestroyable
{
	/**
	 * Sorting function for Array<FlxFrame>#sort(),
	 * e.g. "tiles-001.png", "tiles-003.png", "tiles-002.png".
	 */
	public static function sortByName(frame1:FlxFrame, frame2:FlxFrame, prefixLength:Int, postfixLength:Int):Int
	{
		var name1:String = frame1.name;
		var name2:String = frame2.name;
		
		var num1:Int = Std.parseInt(name1.substring(prefixLength, name1.length - postfixLength));
		var num2:Int = Std.parseInt(name2.substring(prefixLength, name2.length - postfixLength));
		
		return num1 - num2;
	}
	
	public var name:String;
	/**
	 * Region of image to render
	 */
	public var frame(default, set):FlxRect;
	
	/**
	 * UV coordinates for this frame.
	 * WARNING: In optimization purposes width and height of this rect contain right and bottom coordinates (x + width and y + height).
	 */
	public var uv:FlxRect;
	
	public var parent:FlxGraphic;
	
	/**
	 * Rotation angle of this frame. 
	 * Required for packed atlas images.
	 */
	public var angle:FlxFrameAngle;
	
	/**
	 * Original (uncropped) image size.
	 */
	public var sourceSize(default, null):FlxPoint;
	/**
	 * Frame offset from top left corner of original image.
	 */
	public var offset(default, null):FlxPoint;
	
	/**
	 * The type of this frame.
	 */
	public var type:FlxFrameType;
	
	@:allow(flixel)
	private function new(parent:FlxGraphic, angle:FlxFrameAngle = 0)
	{
		this.parent = parent;
		this.angle = angle;
		type = FlxFrameType.REGULAR;
		
		sourceSize = FlxPoint.get();
		offset = FlxPoint.get();
	}
	
	/**
	 * Applies frame rotation to the specified matrix, which should be used for tiling or blitting.
	 * Required for rotated frame support.
	 * 
	 * @param	mat		Matrix to transform / rotate
	 * @param	blit	Whether specified matrix will be used for blitting or for tile rendering.
	 * @return	Transformed matrix.
	 */
	private inline function prepareBlitMatrix(mat:FlxMatrix, blit:Bool = true):FlxMatrix
	{
		mat.identity();
		
		if (blit)
			mat.translate( -frame.x, -frame.y);
		
		if (angle == FlxFrameAngle.ANGLE_90)
		{
			mat.rotateByPositive90();
			mat.translate(frame.height, 0);
		}
		else if (angle == FlxFrameAngle.ANGLE_NEG_90)
		{
			mat.rotateByNegative90();
			mat.translate(0, frame.width);
		}
		
		mat.translate(offset.x, offset.y);
		return mat;
	}
	
	/**
	 * Rotates and flips matrix. This method expects matrix which were prepared by prepareBlitMatrix() method.
	 * Internal use only.
	 * 
	 * @param	mat			Matrix to transform
	 * @param	rotation	Rotation to apply to specified matrix. This method expects only 0, 90 and -90 degrees values.
	 * @param	flipX		Do we need to flip frame horizontally
	 * @param	flipY		Do we need to flip frame vertically
	 * @return	Transformed matrix with applied rotation and flipping
	 */
	private inline function rotateAndFlip(mat:FlxMatrix, rotation:FlxFrameAngle = FlxFrameAngle.ANGLE_0, flipX:Bool = false, flipY:Bool = false):FlxMatrix
	{
		var w:Int = Std.int(sourceSize.x);
		var h:Int = Std.int(sourceSize.y);
		
		// rotate frame transformation matrix if rotation isn't zero
		if (rotation != FlxFrameAngle.ANGLE_0)
		{
			var t:Int = w;
			w = h;
			h = t;
			
			if (rotation == FlxFrameAngle.ANGLE_90)
			{
				mat.rotateByPositive90();
				mat.translate(sourceSize.y, 0);
			}
			else if (rotation == FlxFrameAngle.ANGLE_270 || rotation == FlxFrameAngle.ANGLE_NEG_90)
			{
				mat.rotateByNegative90();
				mat.translate(0, sourceSize.x);
			}
		}
		
		// flip frame transformation matrix
		if (flipX)
		{
			mat.scale( -1, 1);
			mat.translate(w, 0);
		}
		
		if (flipY)
		{
			mat.scale(1, -1);
			mat.translate(0, h);
		}
		
		return mat;
	}
	
	/**
	 * Prepares matrix for frame blitting (see "paint" methods).
	 * 
	 * @param	mat			Matrix to transform/prepare
	 * @param	rotation	Rotation to apply to specified matrix. This method expects only 0, 90 and -90 degrees values.
	 * @param	flipX		Do we need to flip frame horizontally
	 * @param	flipY		Do we need to flip frame vertically
	 * @return	Tranformed matrix which can be used for frame painting.
	 */
	private function prepareTransformedBlitMatrix(mat:FlxMatrix, rotation:FlxFrameAngle = FlxFrameAngle.ANGLE_0, flipX:Bool = false, flipY:Bool = false):FlxMatrix
	{
		mat = prepareBlitMatrix(mat);
		return rotateAndFlip(mat, rotation, flipX, flipY);
	}
	
	/**
	 * Prepares matrix for frame tile/triangles rendering.
	 * 
	 * @param	mat			Matrix to transform/prepare
	 * @param	rotation	Rotation to apply to specified matrix. This method expects only 0, 90 and -90 degrees values.
	 * @param	flipX		Do we need to flip frame horizontally
	 * @param	flipY		Do we need to flip frame vertically
	 * @return	Tranformed matrix which can be used for frame drawing.
	 */
	public function prepareMatrix(mat:FlxMatrix, rotation:FlxFrameAngle = FlxFrameAngle.ANGLE_0, flipX:Bool = false, flipY:Bool = false):FlxMatrix
	{
		#if FLX_RENDER_BLIT
		mat.identity();
		return mat;
		#else
		prepareBlitMatrix(mat, false);
		return rotateAndFlip(mat, rotation, flipX, flipY);
		#end
	}
	
	/**
	 * Draws frame on specified BitmapData object.
	 * 
	 * @param	bmd					BitmapData object to draw this frame on. If bmd is null then new BitmapData created
	 * @param	point				Where to draw this frame on specified BitmapData object
	 * @param	mergeAlpha			Whether to merge alphas or not (works like with BitmapData's copyPixels() method). Default value is false
	 * @param	disposeIfNotEqual	Whether dispose passed bmd or not if its size isn't equal to frame's original size (sourceSize)
	 * @return	Modified or newly created BitmapData with frame image on it
	 */
	public function paint(bmd:BitmapData = null, point:Point = null, mergeAlpha:Bool = false, disposeIfNotEqual:Bool = false):BitmapData
	{
		if (point == null)
		{
			point = FlxPoint.point1;
			point.setTo(0, 0);
		}
		
		bmd = checkInputBitmap(bmd, point, FlxFrameAngle.ANGLE_0, mergeAlpha, disposeIfNotEqual);
		
		if (type == FlxFrameType.EMPTY)
		{
			return bmd;
		}
		
		if (angle == FlxFrameAngle.ANGLE_0)
		{
			offset.copyToFlash(FlxPoint.point2);
			FlxPoint.point2.x += point.x;
			FlxPoint.point2.y += point.y;
			bmd.copyPixels(parent.bitmap, frame.copyToFlash(FlxRect.rect), FlxPoint.point2, null, null, mergeAlpha);
		}
		else
		{
			var matrix:FlxMatrix = FlxMatrix.matrix;
			prepareBlitMatrix(matrix);
			matrix.translate(point.x, point.y);
			var rect:Rectangle = getDrawFrameRect(matrix);
			bmd.draw(parent.bitmap, matrix, null, null, rect);
		}
		
		return bmd;
	}
	
	/**
	 * Draws rotated and flipped frame on specified BitmapData object.
	 * 
	 * @param	bmd					BitmapData object to draw this frame on. If bmd is null then new BitmapData created
	 * @param	point				Where to draw this frame on specified BitmapData object
	 * @param	rotation			How much rotate the frame. Works only with 0, 90 and -90 (which is the same as 270) values
	 * @param	flipX				Do we need to flip frame horizontally
	 * @param	flipY				Do we need to flip frame vertically
	 * @param	mergeAlpha			Whether to merge alphas or not (works like with BitmapData's copyPixels() method). Default value is false
	 * @param	disposeIfNotEqual	Whether dispose passed bmd or not if its size isn't equal to frame's original size (sourceSize)
	 * @return	Modified or newly created BitmapData with frame image on it
	 */
	public function paintRotatedAndFlipped(bmd:BitmapData = null, point:Point = null, rotation:FlxFrameAngle = FlxFrameAngle.ANGLE_0, flipX:Bool = false, flipY:Bool = false, mergeAlpha:Bool = false, disposeIfNotEqual:Bool = false):BitmapData
	{
		if (type == FlxFrameType.EMPTY && rotation == FlxFrameAngle.ANGLE_0)
		{
			return paint(bmd, point, mergeAlpha, disposeIfNotEqual);
		}
		
		if (point == null)
		{
			point = FlxPoint.point2;
			point.setTo(0, 0);
		}
		
		bmd = checkInputBitmap(bmd, point, rotation, mergeAlpha, disposeIfNotEqual);
		
		if (type == FlxFrameType.EMPTY)
		{
			return bmd;
		}
		
		var matrix:FlxMatrix = FlxMatrix.matrix;
		prepareTransformedBlitMatrix(matrix, rotation, flipX, flipY);
		matrix.translate(point.x, point.y);
		var rect:Rectangle = getDrawFrameRect(matrix);
		bmd.draw(parent.bitmap, matrix, null, null, rect);
		return bmd;
	}
	
	/**
	 * Internal method which runs few checks on specified BitmapData object.
	 * 
	 * @param	bmd					BitmapData object to check againist.
	 * @param	point				Optional point for mergeAlpha checks
	 * @param	rotation			How much we will rotate the frame when we will be drawing it on specified BitmapData.
	 * @param	mergeAlpha			Whether to merge alphas or not (works like with BitmapData's copyPixels() method). Default value is false
	 * @param	disposeIfNotEqual	Whether dispose passed bmd or not if its size isn't equal to frame's original size (sourceSize)
	 * @return	Prepared BitmapData for further frame blitting. Output BitmapData could be a different object.
	 */
	private inline function checkInputBitmap(bmd:BitmapData = null, point:Point = null, rotation:FlxFrameAngle = FlxFrameAngle.ANGLE_0, mergeAlpha:Bool = false, disposeIfNotEqual:Bool = false):BitmapData
	{
		var w:Int = Std.int(sourceSize.x);
		var h:Int = Std.int(sourceSize.y);
		
		if (rotation != FlxFrameAngle.ANGLE_0)
		{
			var t:Int = w;
			w = h;
			h = t;
		}
		
		if (bmd != null && disposeIfNotEqual)
		{
			bmd = FlxDestroyUtil.disposeIfNotEqual(bmd, w, h);
		}
		
		if (bmd != null && !mergeAlpha)
		{
			var rect:Rectangle = FlxRect.rect;
			rect.setTo(point.x, point.y, w, h);
			bmd.fillRect(rect, FlxColor.TRANSPARENT);
		}
		else if (bmd == null)
		{
			bmd = new BitmapData(w, h, true, FlxColor.TRANSPARENT);
		}
		
		return bmd;
	}
	
	/**
	 * Internal method which prepares frame rect for blitting.
	 * Required for rotated frames support.
	 * 
	 * @param	mat	frame transformation matrix (rotated / flipped / translated)
	 * @return	Clipping rectangle which will be used for frame blitting
	 */
	private inline function getDrawFrameRect(mat:FlxMatrix):Rectangle
	{
		var p1:FlxPoint = FlxPoint.flxPoint1.set(frame.x, frame.y);
		var p2:FlxPoint = FlxPoint.flxPoint2.set(frame.right, frame.bottom);
		
		p1.transform(mat);
		p2.transform(mat);
		
		var flxRect:FlxRect = FlxRect.flxRect.fromTwoPoints(p1, p2);
		var rect:Rectangle = FlxRect.rect;
		flxRect.copyToFlash(rect);
		return rect;
	}
	
	/**
	 * Generates frame with specified subregion of this frame
	 * 
	 * @param	rect			frame region to generate frame for
	 * @param	frameToFill		frame to fill with data. If null then new frame will be created
	 * @return	Specified frameToFill object but filled with data
	 */
	public function subFrameTo(rect:FlxRect, frameToFill:FlxFrame = null):FlxFrame
	{
		var p:FlxGraphic = parent;
		var a:FlxFrameAngle = angle;
		
		var sx:Float = sourceSize.x;
		var sy:Float = sourceSize.y;
		
		var fx:Float = frame.x;
		var fy:Float = frame.y;
		var fw:Float = frame.width;
		var fh:Float = frame.height;
		
		var ox:Float = offset.x;
		var oy:Float = offset.y;
		
		var t:FlxFrameType = type;
		
		if (frameToFill == null)
		{
			frameToFill = new FlxFrame(p, a);
		}
		else
		{
			frameToFill.parent = p;
			frameToFill.angle = a;
			frameToFill.frame = FlxDestroyUtil.put(frameToFill.frame);
		}
		
		frameToFill.sourceSize.set(rect.width, rect.height);
		
		// no need to make all calculations if original frame is empty...
		if (t == FlxFrameType.EMPTY)
		{
			frameToFill.type = FlxFrameType.EMPTY;
			frameToFill.offset.set(0, 0);
			return frameToFill;
		}
		
		var clippedRect:FlxRect = FlxRect.get().setSize(fw, fh);
		if (a != FlxFrameAngle.ANGLE_0)
		{
			clippedRect.width = fh;
			clippedRect.height = fw;
		}
		
		rect.offset( -ox, -oy);
		var frameRect:FlxRect = clippedRect.intersection(rect);
		FlxDestroyUtil.put(clippedRect);
		
		if (frameRect.isEmpty)
		{
			frameToFill.type = FlxFrameType.EMPTY;
			frameRect.set(0, 0, 0, 0);
			frameToFill.frame = frameRect;
			frameToFill.offset.set(0, 0);
		}
		else
		{
			frameToFill.type = FlxFrameType.REGULAR;
			frameToFill.offset.set(frameRect.x, frameRect.y).subtract(rect.x, rect.y);
			
			var p1:FlxPoint = FlxPoint.flxPoint1.set(frameRect.x, frameRect.y);
			var p2:FlxPoint = FlxPoint.flxPoint2.set(frameRect.right, frameRect.bottom);
			
			var mat:FlxMatrix = FlxMatrix.matrix;
			mat.identity();
			
			if (a == FlxFrameAngle.ANGLE_NEG_90)
			{
				mat.rotateByPositive90();
				mat.translate(sy, 0);
			}
			else if (a == FlxFrameAngle.ANGLE_90)
			{
				mat.rotateByNegative90();
				mat.translate(0, sx);
			}
			
			if (a != FlxFrameAngle.ANGLE_0)
			{
				p1.transform(mat);
				p2.transform(mat);
			}
			
			frameRect.fromTwoPoints(p1, p2);
			frameRect.offset(fx, fy);
			
			frameToFill.frame = frameRect;
		}
		
		rect.offset(ox, oy);
		return frameToFill;
	}
	
	// TODO: implement it and document it...
	/**
	 * 
	 * 
	 * @param	border
	 * @return
	 */
	public function setBorder(border:FlxPoint):FlxFrame
	{
		var rect:FlxRect = FlxRect.get(border.x, border.y, sourceSize.x - 2 * border.x, sourceSize.y - 2 * border.y);
		this.subFrameTo(rect, this);
		FlxDestroyUtil.put(rect);
		return this;
	}
	
	/**
	 * Frame clipping
	 * @param	clip			Clipping rectangle to apply on frame
	 * @param	clippedFrame	The frame which will contain result of original frame clipping. If null then new frame will be created.
	 * @return	Result of applying frame clipping
	 */
	public function clipTo(clip:FlxRect, clippedFrame:FlxFrame = null):FlxFrame
	{
		if (clippedFrame == null)
		{
			clippedFrame = new FlxFrame(parent, angle);
		}
		else
		{
			clippedFrame.parent = parent;
			clippedFrame.angle = angle;
			clippedFrame.frame = FlxDestroyUtil.put(clippedFrame.frame);
			clippedFrame.uv = FlxDestroyUtil.put(clippedFrame.uv);
		}
		
		clippedFrame.sourceSize.copyFrom(sourceSize);
		
		// no need to make all calculations if original frame is empty...
		if (type == FlxFrameType.EMPTY)
		{
			clippedFrame.type = FlxFrameType.EMPTY;
			clippedFrame.offset.set(0, 0);
			return clippedFrame;
		}
		
		var clippedRect:FlxRect = FlxRect.get().setSize(frame.width, frame.height);
		if (angle != FlxFrameAngle.ANGLE_0)
		{
			clippedRect.width = frame.height;
			clippedRect.height = frame.width;
		}
		
		clip.offset( -offset.x, -offset.y);
		var frameRect:FlxRect = clippedRect.intersection(clip);
		FlxDestroyUtil.put(clippedRect);
		clip.offset(offset.x, offset.y);
		
		if (frameRect.isEmpty)
		{
			clippedFrame.type = FlxFrameType.EMPTY;
			frameRect.set(0, 0, 0, 0);
			clippedFrame.frame = frameRect;
			clippedFrame.offset.set(0, 0);
		}
		else
		{
			clippedFrame.type = FlxFrameType.REGULAR;
			clippedFrame.offset.set(frameRect.x, frameRect.y).addPoint(offset);
			
			var p1:FlxPoint = FlxPoint.flxPoint1.set(frameRect.x, frameRect.y);
			var p2:FlxPoint = FlxPoint.flxPoint2.set(frameRect.right, frameRect.bottom);
			
			var mat:FlxMatrix = FlxMatrix.matrix;
			mat.identity();
			
			if (angle == FlxFrameAngle.ANGLE_NEG_90)
			{
				mat.rotateByPositive90();
				mat.translate(sourceSize.y, 0);
			}
			else if (angle == FlxFrameAngle.ANGLE_90)
			{
				mat.rotateByNegative90();
				mat.translate(0, sourceSize.x);
			}
			
			if (angle != FlxFrameAngle.ANGLE_0)
			{
				p1.transform(mat);
				p2.transform(mat);
			}
			
			frameRect.fromTwoPoints(p1, p2);
			frameRect.offset(frame.x, frame.y);
			
			clippedFrame.frame = frameRect;
		}
		
		return clippedFrame;
	}
	
	public function copyTo(clone:FlxFrame = null):FlxFrame
	{
		if (clone == null)
		{
			clone = new FlxFrame(parent, angle);
		}
		else
		{
			clone.parent = parent;
			clone.angle = angle;
			clone.frame = FlxDestroyUtil.put(clone.frame);
		}
		
		clone.offset.copyFrom(offset);
		clone.sourceSize.copyFrom(sourceSize);
		clone.frame = FlxRect.get().copyFrom(frame);
		clone.type = type;
		return clone;
	}
	
	public function destroy():Void
	{
		name = null;
		parent = null;
		sourceSize = FlxDestroyUtil.put(sourceSize);
		offset = FlxDestroyUtil.put(offset);
		frame = FlxDestroyUtil.put(frame);
		uv = FlxDestroyUtil.put(uv);
	}
	
	public function toString():String
	{
		return FlxStringUtil.getDebugString([
			LabelValuePair.weak("name", name)]);
	}
	
	private function set_frame(value:FlxRect):FlxRect
	{
		if (value != null)
		{
			if (uv == null)
				uv = FlxRect.get();
			
			uv.set(value.x / parent.width, value.y / parent.height, value.right / parent.width, value.bottom / parent.height);
		}
		
		return frame = value;
	}
}

/**
 * Just enumeration of all types of frames.
 * Added for faster type detection with less usage of casting.
 */
@:enum
abstract FlxFrameType(Int) 
{
	var REGULAR		= 0;
	var EMPTY		= 2;
	var GLYPH		= 3;
}

@:enum
abstract FlxFrameAngle(Int) from Int to Int
{
	var ANGLE_0			= 0;
	var ANGLE_90		= 90;
	var ANGLE_NEG_90	= -90;
	var ANGLE_270		= -90;
}