/*
 * format - haXe File Formats
 *
 *  SWF File Format
 *  Copyright (C) 2004-2008 Nicolas Cannasse
 *
 * Copyright (c) 2008, The haXe Project Contributors
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE HAXE PROJECT CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE HAXE PROJECT CONTRIBUTORS BE LIABLE FOR
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 */
package format.swf;

typedef Fixed = #if haxe3 Int #else haxe.Int32 #end;
typedef Fixed8 = Int;

typedef SWF = {
	var header : SWFHeader;
	var tags : Array<SWFTag>;
}

enum SWFTag {
	TShowFrame;
	TShape( id : Int, version : Int, data : haxe.io.Bytes );
	TMorphShape( id : Int, version : Int, data : haxe.io.Bytes );
	TBackgroundColor( color : Int );
	TDoActions( data : haxe.io.Bytes );
	TClip( id : Int, frames : Int, tags : Array<SWFTag> );
	TPlaceObject2( po : PlaceObject );
	TPlaceObject3( po : PlaceObject );
	TRemoveObject2( depth : Int );
	TFrameLabel( label : String, anchor : Bool );
	TExport( el : Array<{ cid : Int, name : String }> );
	TDoInitActions( id : Int, data : haxe.io.Bytes );
	TActionScript3( data : haxe.io.Bytes, ?context : AS3Context );
	TSymbolClass( symbols : Array<{ cid : Int, className : String }> );
	TSandBox( v : Int );
	TBitsLossless( data : Lossless );
	TBitsLossless2( data : Lossless );
	TBitsJPEG2( id: Int, data: haxe.io.Bytes );
	TBitsJPEG3( id: Int, data: haxe.io.Bytes, mask: haxe.io.Bytes );
	TBinaryData( id : Int, data : haxe.io.Bytes );
	TSound( data : Sound );
	TDefineText( dt : DefineText );
	TDefineText2( dt : DefineText );
	TDefineEditText( dt : DefineEditText );
	TUnknown( id : Int, data : haxe.io.Bytes );
}

typedef SWFHeader = {
	var version : Int;
	var compressed : Bool;
	var width : Int;
	var height : Int;
	var fps : Float;
	var nframes : Int;
}

typedef AS3Context = {
	var id : Int;
	var label : String;
}

class PlaceObject {
	public var depth : Int;
	public var move : Bool;
	public var cid : Null<Int>;
	public var matrix : Null<Matrix>;
	public var color : Null<CXA>;
	public var ratio : Null<Int>;
	public var instanceName : Null<String>;
	public var clipDepth : Null<Int>;
	public var events : Null<Array<ClipEvent>>;
	public var filters : Null<Array<Filter>>;
	public var blendMode : Null<BlendMode>;
	public var bitmapCache : Null<Int>;
	public var hasImage : Bool;
	public var className : Null<String>;
	public function new() {
	}
}

typedef MatrixPart = {
	var nbits : Int;
	var x : Int;
	var y : Int;
}

typedef Matrix = {
	var scale : Null<MatrixPart>;
	var rotate : Null<MatrixPart>;
	var translate : MatrixPart;
}

typedef RGBA = {
	var r : Int;
	var g : Int;
	var b : Int;
	var a : Int;
}

typedef CXA = {
	var nbits : Int;
	var add : Null<RGBA>;
	var mult : Null<RGBA>;
}

typedef ClipEvent = {
	var eventsFlags : Int;
	var data : haxe.io.Bytes;
}

enum BlendMode {
	BNormal;
	BLayer;
	BMultiply;
	BScreen;
	BLighten;
	BDarken;
	BDifference;
	BAdd;
	BSubtract;
	BInvert;
	BAlpha;
	BErase;
	BOverlay;
	BHardLight;
}

enum Filter {
	FDropShadow( data : FilterData );
	FBlur( data : BlurFilterData );
	FGlow( data : FilterData );
	FBevel( data : FilterData );
	FGradientGlow( data : GradientFilterData );
	FColorMatrix( data : Array<Float> );
	FGradientBevel( data : GradientFilterData );
}

typedef FilterFlags = {
	var inner : Bool;
	var knockout : Bool;
	var ontop : Bool;
	var passes : Int;
}

typedef FilterData = {
	var color : RGBA;
	var color2 : RGBA;
	var blurX : Fixed;
	var blurY : Fixed;
	var angle : Fixed;
	var distance : Fixed;
	var strength : Fixed8;
	var flags : FilterFlags;
}

typedef BlurFilterData = {
	var blurX : Fixed;
	var blurY : Fixed;
	var passes : Int;
}

typedef GradientFilterData = {
	var colors : Array<{ color : RGBA, position : Int }>;
	var data : FilterData;
}

typedef Lossless = {
	var cid : Int;
	var color : ColorModel;
	var width : Int;
	var height : Int;
	var data : haxe.io.Bytes;
}

enum ColorModel {
	CM8Bits( ncolors : Int ); // Lossless2 contains ARGB palette
	CM15Bits; // Lossless only
	CM24Bits; // Lossless only
	CM32Bits; // Lossless2 only
}

typedef Sound = {
	var sid : Int;
	var format : SoundFormat;
	var rate : SoundRate;
	var is16bit : Bool;
	var isStereo : Bool;
	var samples : #if haxe3 Int #else haxe.Int32 #end;
	var data : SoundData;
};

enum SoundData {
	SDMp3( seek : Int, data : haxe.io.Bytes );
	SDOther( data : haxe.io.Bytes );
}

enum SoundFormat {
   SFNativeEndianUncompressed;
   SFADPCM;
   SFMP3;
   SFLittleEndianUncompressed;
   SFNellymoser16k;
   SFNellymoser8k;
   SFNellymoser;
   SFSpeex;
}

/**
 * Sound sampling rate.
 *
 * - 5k is not allowed for MP3
 * - Nellymoser and Speex ignore this option
 */
enum SoundRate {
   SR5k;  // 5512 Hz
   SR11k; // 11025 Hz
   SR22k; // 22050 Hz
   SR44k; // 44100 Hz
}

typedef TextRecord = {
	var fontId : Null<Int>;
	var textColor : Null<Fixed>;
	var xOffset : Null<Int>;
	var yOffset : Null<Int>;
	var textHeight : Null<Int>;
	var glyphEntries : Array<{
		var glyphIndex : Int;
		var glyphAdvance : Int;
	}>;
};

typedef DefineText = {
	var cid : Int;
	var textBounds : {
		var left : Int;
		var right : Int;
		var top : Int;
		var bottom : Int;
	};
	var textMatrix : Matrix;
	var glyphBits: Int;
	var advanceBits: Int;
	var textRecords: Array<TextRecord>;
};

enum DefineEditTextAlign {
	ALeft;
	ARight;
	ACenter;
	AJustify;
}

typedef DefineEditText = {
	var cid : Int;
	var bounds : {
		var left : Int;
		var right : Int;
		var top : Int;
		var bottom : Int;
	};
	var wordWrap : Bool;
	var multiline : Bool;
	var password : Bool;
	var readOnly : Bool;
	var autoSize : Bool;
	var noSelect : Bool;
	var border : Bool;
	var wasStatic : Bool;
	var html : Bool;
	var useOutlines : Bool;
	var fontId : Null<Int>;
	var fontClass : Null<String>;
	var fontHeight : Null<Int>;
	var textColor : Null<RGBA>;
	var maxLength : Null<Int>;
	var align : Null<DefineEditTextAlign>;
	var leftMargin : Null<Int>;
	var rightMargin : Null<Int>;
	var indent : Null<Int>;
	var leading : Null<Int>;
	var variableName : String;
	var initialText : Null<String>;
};
