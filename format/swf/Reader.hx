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
import format.swf.Data;
import format.swf.Constants;

class Reader {

	var i : haxe.io.Input;
	var bits : format.tools.BitsInput;
	var version : Int;

	public function new(i) {
		this.i = i;
	}

	inline function readFixed8() {
		return i.readUInt16();
	}

	inline function readFixed() {
		return i.readInt32();
	}

	function readUTF8Bytes() {
		var b = new haxe.io.BytesBuffer();
		while( true ) {
			var c = i.readByte();
			if( c == 0 ) break;
			b.addByte(c);
		}
		return b.getBytes();
	}

	function readSignedBits( nbits : Int ) {
		var sign = bits.readBit();
		var n = bits.readBits(nbits - 1);
		return sign ? n - (1 << (nbits - 1)) : n;
	}

	function readRect() {
		bits.reset();
		var nbits = bits.readBits(5);
		return {
			left : readSignedBits(nbits),
			right : readSignedBits(nbits),
			top : readSignedBits(nbits),
			bottom : readSignedBits(nbits),
		};
	}

	function readMatrixPart() : MatrixPart {
		var nbits = bits.readBits(5);
		return {
			nbits : nbits,
			x : bits.readBits(nbits),
			y : bits.readBits(nbits),
		};
	}

	function readMatrix() : Matrix {
		bits.reset();
		return {
			scale : if( bits.readBit() ) readMatrixPart() else null,
			rotate : if( bits.readBit() ) readMatrixPart() else null,
			translate : readMatrixPart(),
		};
	}

	function readRGBA() : RGBA {
		return {
			r : i.readByte(),
			g : i.readByte(),
			b : i.readByte(),
			a : i.readByte(),
		};
	}

	function readCXAColor(nbits) : RGBA {
		return {
			r : bits.readBits(nbits),
			g : bits.readBits(nbits),
			b : bits.readBits(nbits),
			a : bits.readBits(nbits),
		};
	}

	function readCXA() : CXA {
		bits.reset();
		var add = bits.readBit();
		var mult = bits.readBit();
		var nbits = bits.readBits(4);
		return {
			nbits : nbits,
			mult : if( mult ) readCXAColor(nbits) else null,
			add : if( add ) readCXAColor(nbits) else null,
		};
	}

	inline function readInt() {
		#if haxe3
		return i.readInt32();
		#else
		return i.readUInt30();
		#end
	}

	function readClipEvents() : Array<ClipEvent> {
		if( i.readUInt16() != 0 ) throw error();
		readInt(); // all events flags
		var a = new Array();
		while( true ) {
			var code = readInt();
			if( code == 0 ) break;
			var data = i.read(readInt());
			a.push({ eventsFlags : code, data : data });
		}
		return a;
	}

	function readFilterFlags(top) {
		var flags = i.readByte();
		return {
			inner : flags & 128 != 0,
			knockout : flags & 64 != 0,
			// composite : flags & 32 != 0, // always 1 ?
			ontop : top ? (flags & 16 != 0) : false,
			passes : flags & (top ? 15 : 31),
		};
	}

	function readFilterGradient() : GradientFilterData {
		var ncolors = i.readByte();
		var colors = new Array();
		for( i in 0...ncolors )
			colors.push({ color : readRGBA(), position : 0 });
		for( c in colors )
			c.position = i.readByte();
		var data : FilterData = {
			color : null,
			color2 : null,
			blurX : readFixed(),
			blurY : readFixed(),
			angle : readFixed(),
			distance : readFixed(),
			strength : readFixed8(),
			flags : readFilterFlags(true),
		};
		return {
			colors : colors,
			data : data,
		};
	}

	function readFilter() {
		var n = i.readByte();
		return switch( n ) {
			case 0: FDropShadow({
				color : readRGBA(),
				color2 : null,
				blurX : readFixed(),
				blurY : readFixed(),
				angle : readFixed(),
				distance : readFixed(),
				strength : readFixed8(),
				flags : readFilterFlags(false),
			});
			case 1: FBlur({
				blurX : readFixed(),
				blurY : readFixed(),
				passes : i.readByte() >> 3
			});
			case 2: FGlow({
				color : readRGBA(),
				color2 : null,
				blurX : readFixed(),
				blurY : readFixed(),
				angle : #if haxe3 0 #else haxe.Int32.ofInt(0) #end,
				distance : #if haxe3 0 #else haxe.Int32.ofInt(0) #end,
				strength : readFixed8(),
				flags : readFilterFlags(false),
			});
			case 3: FBevel({
				color : readRGBA(),
				color2 : readRGBA(),
				blurX : readFixed(),
				blurY : readFixed(),
				angle : readFixed(),
				distance : readFixed(),
				strength : readFixed8(),
				flags : readFilterFlags(true),
			});
			case 5:
				// ConvolutionFilter
				throw error();
			case 4: FGradientGlow(readFilterGradient());
			case 6:
				var a = new Array();
				for( n in 0...20 )
					a.push(i.readFloat());
				FColorMatrix(a);
			case 7: FGradientBevel(readFilterGradient());
			default:
				throw error();
				null;
		}
	}

	function readFilters() {
		var filters = new Array();
		for( i in 0...i.readByte() )
			filters.push(readFilter());
		return filters;
	}

	function error() {
		return "Invalid SWF";
	}

	public function readHeader() : SWFHeader {
		var tag = i.readString(3);
		var compressed;
		if( tag == "CWS" )
			compressed = true;
		else if( tag == "FWS" )
			compressed = false;
		else
			throw error();
		version = i.readByte();
		var size = readInt();
		if( compressed ) {
			var bytes = format.tools.Inflate.run(i.readAll());
			if( bytes.length + 8 != size ) throw error();
			i = new haxe.io.BytesInput(bytes);
		}
		bits = new format.tools.BitsInput(i);
		var r = readRect();
		if( r.left != 0 || r.top != 0 )
			throw error();
		var fps = i.readByte() / 256.0;
		fps += i.readByte();
		var nframes = i.readUInt16();
		return {
			version : version,
			compressed : compressed,
			width : Std.int(r.right/20),
			height : Std.int(r.bottom/20),
			fps : fps,
			nframes : nframes,
		};
	}

	public function readTagList() {
		var a = new Array();
		while( true ) {
			var t = readTag();
			if( t == null )
				break;
			a.push(t);
		}
		return a;
	}

	function readShape(len,ver) {
		var id = i.readUInt16();
		return TShape(id,ver,i.read(len - 2));
	}

	function readBlendMode() {
		return switch( i.readByte() ) {
		case 0,1: BNormal;
		case 2: BLayer;
		case 3: BMultiply;
		case 4: BScreen;
		case 5: BLighten;
		case 6: BDarken;
		case 7: BDifference;
		case 8: BAdd;
		case 9: BSubtract;
		case 10: BInvert;
		case 11: BAlpha;
		case 12: BErase;
		case 13: BOverlay;
		case 14: BHardLight;
		default: throw error();
		}
	}

	function readPlaceObject(v3) : PlaceObject {
		var f = i.readByte();
		var f2 = if( v3 ) i.readByte() else 0;
		if( f2 >> 5 != 0 ) throw error(); // unsupported bit flags
		var po = new PlaceObject();
		po.depth = i.readUInt16();
		if( f2 & 8 != 0 || (f2 & 16 != 0 && f & 2 != 0) ) po.className = readUTF8Bytes().toString();
		if( f & 1 != 0 ) po.move = true;
		if( f & 2 != 0 ) po.cid = i.readUInt16();
		if( f & 4 != 0 ) po.matrix = readMatrix();
		if( f & 8 != 0 ) po.color = readCXA();
		if( f & 16 != 0 ) po.ratio = i.readUInt16();
		if( f & 32 != 0 ) po.instanceName = readUTF8Bytes().toString();
		if( f & 64 != 0 ) po.clipDepth = i.readUInt16();
		if( f2 & 1 != 0 ) po.filters = readFilters();
		if( f2 & 2 != 0 ) po.blendMode = readBlendMode();
		if( f2 & 4 != 0 ) po.bitmapCache = i.readByte();
		if( f2 & 16 != 0 ) po.hasImage = true;
		if( f & 128 != 0 ) po.events = readClipEvents();
		return po;
	}

	function readLossless(len,v2) {
		var cid = i.readUInt16();
		var bits = i.readByte();
		return {
			cid : cid,
			width : i.readUInt16(),
			height : i.readUInt16(),
			color : switch( bits ) {
				case 3: CM8Bits(i.readByte());
				case 4: CM15Bits;
				case 5: if( v2 ) CM32Bits else CM24Bits;
				default: throw error();
			},
			data : i.read(len - ((bits==3)?8:7)),
		};
	}

	function readSound( len : Int ) {
		var sid = i.readUInt16();
		bits.reset();
		var soundFormat = switch( bits.readBits(4) ) {
			case 0: SFNativeEndianUncompressed;
			case 1: SFADPCM;
			case 2: SFMP3;
			case 3: SFLittleEndianUncompressed;
			case 4: SFNellymoser16k;
			case 5: SFNellymoser8k;
			case 6: SFNellymoser;
			case 11: SFSpeex;
			default: throw error();
		};
		var soundRate = switch( bits.readBits(2) ) {
			case 0: SR5k;
			case 1: SR11k;
			case 2: SR22k;
			case 3: SR44k;
			default: throw error();
		};
		var is16bit = bits.readBit();
		var isStereo = bits.readBit();
		var soundSamples = i.readInt32(); // number of pairs in case of stereo
		var sdata = switch (soundFormat) {
			case SFMP3:
				var seek = i.readInt16();
				SDMp3(seek,i.read(len-9));
			default:
				SDOther(i.read(len - 7));
		};
		return TSound({
			sid : sid,
			format : soundFormat,
			rate : soundRate,
			is16bit : is16bit,
			isStereo : isStereo,
			samples : soundSamples,
			data : sdata,
		});
	}

	function readTextRecord(glyphBits, advanceBits, v2) {
		bits.reset();
		if (bits.readBit()) {
			bits.readBits(3); // Must 0;
			var hasFont = bits.readBit();
			var hasColor = bits.readBit();
			var hasYOffset = bits.readBit();
			var hasXOffset = bits.readBit();
			var fontId = hasFont ? i.readUInt16() : null;
			var textColor = hasColor ? v2 ? readFixed() : #if haxe3 i.readUInt24() #else haxe.Int32.ofInt(i.readUInt24()) #end : null;
			var xOffset = hasXOffset ? i.readInt16() : null;
			var yOffset = hasYOffset ? i.readInt16() : null;
			var textHeight = hasFont ? i.readUInt16() : null;
			var glyphCount = i.readByte();
			var glyphEntries = [
				for ( i in 0...glyphCount ) {
					var glyphIndex = bits.readBits(glyphBits);
					var glyphAdvance = bits.readBits(advanceBits);
					{
						glyphIndex : glyphIndex,
						glyphAdvance : glyphAdvance,
					}
				}
			];
			return {
				fontId : fontId,
				textColor : textColor,
				xOffset : xOffset,
				yOffset : yOffset,
				textHeight : textHeight,
				glyphEntries : glyphEntries,
			};
		} else {
			return null;
		}
	}
	
	function readDefineText( v2 : Bool ) {
		var cid = i.readUInt16();
		var textBounds = readRect();
		var textMatrix = readMatrix();
		var glyphBits = i.readByte();
		var advanceBits = i.readByte();
		var textRecords = [];
		var textRecord = readTextRecord(glyphBits, advanceBits, v2);
		while (textRecord != null)
		{
			textRecords.push(textRecord);
			textRecord = readTextRecord(glyphBits, advanceBits, v2);
		}
		return {
			cid : cid,
			textBounds : textBounds,
			textMatrix : textMatrix,
			glyphBits : glyphBits,
			advanceBits : advanceBits,
			textRecords : textRecords,
		}
	}
	
	static var ALIGN_ENUMS(default, never) = Type.allEnums(DefineEditTextAlign);
	
	function readDefineEditText() {
		var cid = i.readUInt16();
		var bounds = readRect();
		bits.reset();
		var hasText = bits.readBit();
		var wordWrap = bits.readBit();
		var multiline = bits.readBit();
		var password = bits.readBit();
		var readOnly = bits.readBit();
		var hasTextColor = bits.readBit();
		var hasMaxLength = bits.readBit();
		var hasFont = bits.readBit();
		var hasFontClass = bits.readBit();
		var autoSize = bits.readBit();
		var hasLayout = bits.readBit();
		var noSelect = bits.readBit();
		var border = bits.readBit();
		var wasStatic = bits.readBit();
		var html = bits.readBit();
		var useOutlines = bits.readBit();
		var fontId = hasFont ? i.readUInt16() : null;
		var fontClass = hasFontClass ? readUTF8Bytes().toString() : null;
		var fontHeight = hasFont ? i.readUInt16() : null;
		var textColor = hasTextColor ? readRGBA() : null;
		var maxLength = hasMaxLength ? i.readUInt16() : null;
		var align = hasLayout ? ALIGN_ENUMS[i.readByte()] : null;
		var leftMargin = hasLayout ? i.readUInt16() : null;
		var rightMargin = hasLayout ? i.readUInt16() : null;
		var indent = hasLayout ? i.readUInt16() : null;
		var leading = hasLayout ? i.readInt16() : null;
		var variableName = readUTF8Bytes().toString();
		var initialText = hasText ? readUTF8Bytes().toString() : null;
		return {
			cid : cid,
			bounds : bounds,
			wordWrap : wordWrap,
			multiline : multiline,
			password : password,
			readOnly : readOnly,
			autoSize : autoSize,
			noSelect : noSelect,
			border : border,
			wasStatic : wasStatic,
			html : html,
			useOutlines : useOutlines,
			fontId : fontId,
			fontClass : fontClass,
			fontHeight : fontHeight,
			textColor : textColor,
			maxLength : maxLength,
			align : align,
			leftMargin : leftMargin,
			rightMargin : rightMargin,
			indent : indent,
			leading : leading,
			variableName : variableName,
			initialText : initialText,
		};
	}
	
	public function readTag() : SWFTag {
		var h = i.readUInt16();
		var id = h >> 6;
		var len = h & 63;
		var ext = false;
		if( len == 63 ) {
			len = readInt();
			if( len < 63 ) ext = true;
		}
		return switch( id ) {
		case TagId.End:
			null;
		case TagId.ShowFrame:
			TShowFrame;
		case TagId.DefineShape:
			readShape(len,1);
		case TagId.DefineShape2:
			readShape(len,2);
		case TagId.DefineShape3:
			readShape(len,3);
		case TagId.DefineShape4:
			readShape(len,4);
		case TagId.SetBackgroundColor:
			i.bigEndian = true;
			var color = i.readUInt24();
			i.bigEndian = false;
			TBackgroundColor(color);
		case TagId.DefineBitsLossless:
			TBitsLossless(readLossless(len,false));
		case TagId.DefineBitsLossless2:
			TBitsLossless2(readLossless(len,true));
		case TagId.DefineBitsJPEG2:
			var cid = i.readUInt16();
			TBitsJPEG2(cid, i.read(len - 2));
		case TagId.DefineBitsJPEG3:
			var cid = i.readUInt16();
			var dataSize = readInt();
			var data = i.read(dataSize);
			var mask = i.read(len - dataSize - 6);
			TBitsJPEG3(cid, data, mask);
		case TagId.PlaceObject2:
			TPlaceObject2(readPlaceObject(false));
		case TagId.PlaceObject3:
			TPlaceObject3(readPlaceObject(true));
		case TagId.RemoveObject2:
			TRemoveObject2(i.readUInt16());
		case TagId.DefineSprite:
			var cid = i.readUInt16();
			var fcount = i.readUInt16();
			var tags = readTagList();
			TClip(cid,fcount,tags);
		case TagId.FrameLabel:
			var label = readUTF8Bytes();
			var anchor = if( len == label.length + 2 ) i.readByte() == 1 else false;
			TFrameLabel(label.toString(), anchor);
		case TagId.ExportAssets:
			var exports = new Array();
			for( n in 0...i.readUInt16() ) {
				var cid = i.readUInt16();
				var name = readUTF8Bytes().toString();
				exports.push( { cid : cid, name : name } );
			}
			TExport(exports);
		case TagId.DoAction:
			TDoActions(i.read(len));
		case TagId.DoInitAction:
			var cid = i.readUInt16();
			TDoInitActions(cid,i.read(len-2));
		case TagId.FileAttributes:
			TSandBox(readInt());
		case TagId.RawABC:
			TActionScript3(i.read(len),null);
		case TagId.SymbolClass:
			var sl = new Array();
			for( n in 0...i.readUInt16() )
				sl.push({
					cid : i.readUInt16(),
					className : i.readUntil(0),
				});
			TSymbolClass(sl);
		case TagId.DoABC:
			var infos = {
				id : readInt(),
				label : i.readUntil(0),
			};
			len -= 4 + infos.label.length + 1;
			TActionScript3(i.read(len),infos);
		case TagId.DefineBinaryData:
			var id = i.readUInt16();
			if( readInt() != 0 ) throw error();
			TBinaryData(id, i.read(len - 6));
		case TagId.DefineSound:
			readSound(len);
		case TagId.DefineMorphShape:
			var id = i.readUInt16();
			TMorphShape(id,1,i.read(len - 2));
		case TagId.DefineMorphShape2:
			var id = i.readUInt16();
			TMorphShape(id,2,i.read(len - 2));
		case TagId.DefineText:
			TDefineText(readDefineText(false));
		case TagId.DefineText2:
			TDefineText2(readDefineText(true));
		case TagId.DefineEditText:
			TDefineEditText(readDefineEditText());
		default:
			var data = i.read(len);
			TUnknown(id,data);
		}
	}

	public function read() : SWF {
		return {
			header : readHeader(),
			tags : readTagList(),
		};
	}

}
