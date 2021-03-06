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

class Writer {

	var output : haxe.io.Output;
	var o : haxe.io.BytesOutput;
	var compressed : Bool;
	var bits : format.tools.BitsOutput;

	public function new(o) {
		this.output = o;
	}

	public function write( s : SWF ) {
		writeHeader(s.header);
		for( t in s.tags )
			writeTag(t);
		writeEnd();
	}

	function writeSignedBits( nbits : Int, n : Int ) {
		bits.writeBit(n < 0);
		bits.writeBits(nbits - 1, n < 0 ? n + (1 << (nbits - 1)) : n);
	}

	function writeRect(r) {
		var lr = (r.left > r.right) ? r.left : r.right;
		var bt = (r.top > r.bottom) ? r.top : r.bottom;
		var max = (lr > bt) ? lr : bt;
		var nbits = 1; // sign
		while( max > 0 ) {
			max >>= 1;
			nbits++;
		}
		bits.writeBits(5,nbits);
		writeSignedBits(nbits,r.left);
		writeSignedBits(nbits,r.right);
		writeSignedBits(nbits,r.top);
		writeSignedBits(nbits,r.bottom);
		bits.flush();
	}

	inline function writeFixed8(v) {
		o.writeUInt16(v);
	}

	inline function writeFixed(v) {
		o.writeInt32(v);
	}

	function openTMP() {
		var old = o;
		o = new haxe.io.BytesOutput();
		bits.o = o;
		return old;
	}

	function closeTMP(old) {
		var bytes = o.getBytes();
		o = old;
		bits.o = old;
		return bytes;
	}

	public function writeHeader( h : SWFHeader ) {
		compressed = h.compressed;
		output.writeString( compressed ? "CWS" : "FWS" );
		output.writeByte(h.version);
		o = new haxe.io.BytesOutput();
		bits = new format.tools.BitsOutput(o);
		writeRect({ left : 0, top : 0, right : h.width * 20, bottom : h.height * 20 });
		o.writeByte(Std.int(h.fps * 256.0) & 0xFF);
		o.writeByte(Std.int(h.fps) & 0x7F);
		o.writeUInt16(h.nframes);
	}

	function writeRGBA( c : RGBA ) {
		o.writeByte(c.r);
		o.writeByte(c.g);
		o.writeByte(c.b);
		o.writeByte(c.a);
	}

	function writeMatrixPart( m : MatrixPart ) {
		bits.writeBits(5,m.nbits);
		bits.writeBits(m.nbits,m.x);
		bits.writeBits(m.nbits,m.y);
	}

	function writeMatrix( m : Matrix ) {
		if( m.scale != null ) {
			bits.writeBit(true);
			writeMatrixPart(m.scale);
		} else
			bits.writeBit(false);
		if( m.rotate != null ) {
			bits.writeBit(true);
			writeMatrixPart(m.rotate);
		} else
			bits.writeBit(false);
		writeMatrixPart(m.translate);
		bits.flush();
	}

	function writeCXAColor(c:RGBA,nbits) {
		bits.writeBits(nbits,c.r);
		bits.writeBits(nbits,c.g);
		bits.writeBits(nbits,c.b);
		bits.writeBits(nbits,c.a);
	}

	function writeCXA( c : CXA ) {
		bits.writeBit(c.add != null);
		bits.writeBit(c.mult != null);
		bits.writeBits(4,c.nbits);
		if( c.mult != null ) writeCXAColor(c.mult,c.nbits);
		if( c.add != null ) writeCXAColor(c.add,c.nbits);
		bits.flush();
	}

	function writeClipEvents( events : Array<ClipEvent> ) {
		o.writeUInt16(0);
		var all = 0;
		for( e in events )
			all |= e.eventsFlags;
		writeInt(all);
		for( e in events ) {
			writeInt(e.eventsFlags);
			writeInt(e.data.length);
			o.write(e.data);
		}
		writeInt(0);
	}

	function writeFilterFlags(f:FilterFlags,top) {
		var flags = 32;
		if( f.inner ) flags |= 128;
		if( f.knockout ) flags |= 64;
		if( f.ontop ) flags |= 16;
		flags |= f.passes;
		o.writeByte(flags);
	}

	function writeFilterGradient(f:GradientFilterData) {
		o.writeByte(f.colors.length);
		for( c in f.colors )
			writeRGBA(c.color);
		for( c in f.colors )
			o.writeByte(c.position);
		var d = f.data;
		writeFixed(d.blurX);
		writeFixed(d.blurY);
		writeFixed(d.angle);
		writeFixed(d.distance);
		writeFixed8(d.strength);
		writeFilterFlags(d.flags,true);
	}

	function writeFilter( f : Filter ) {
		switch( f ) {
		case FDropShadow(d):
			o.writeByte(0);
			writeRGBA(d.color);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed(d.angle);
			writeFixed(d.distance);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,false);
		case FBlur(d):
			o.writeByte(1);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			o.writeByte(d.passes << 3);
		case FGlow(d):
			o.writeByte(2);
			writeRGBA(d.color);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,false);
		case FBevel(d):
			o.writeByte(3);
			writeRGBA(d.color);
			writeRGBA(d.color2);
			writeFixed(d.blurX);
			writeFixed(d.blurY);
			writeFixed(d.angle);
			writeFixed(d.distance);
			writeFixed8(d.strength);
			writeFilterFlags(d.flags,true);
		case FGradientGlow(d):
			o.writeByte(4);
			writeFilterGradient(d);
		case FColorMatrix(d):
			o.writeByte(6);
			for( f in d )
				o.writeFloat(f);
		case FGradientBevel(d):
			o.writeByte(7);
			writeFilterGradient(d);
		}
	}

	function writeFilters( filters : Array<Filter> ) {
		o.writeByte(filters.length);
		for( f in filters )
			writeFilter(f);
	}

	function writeBlendMode( b : BlendMode ) {
		o.writeByte(Type.enumIndex(b) + 1);
	}

	function writePlaceObject(po:PlaceObject,v3) {
		var f = 0, f2 = 0;
		if( po.move ) f |= 1;
		if( po.cid != null ) f |= 2;
		if( po.matrix != null ) f |= 4;
		if( po.color != null ) f |= 8;
		if( po.ratio != null ) f |= 16;
		if( po.instanceName != null ) f |= 32;
		if( po.clipDepth != null ) f |= 64;
		if( po.events != null ) f |= 128;
		if( po.filters != null ) f2 |= 1;
		if( po.blendMode != null ) f2 |= 2;
		if( po.bitmapCache != null ) f2 |= 4;
		if( po.className != null ) f2 |= 8;
		if( po.hasImage ) f2 |= 16;
		o.writeByte(f);
		if( v3 )
			o.writeByte(f2);
		else if( f2 != 0 )
			throw "Invalid place object version";
		o.writeUInt16(po.depth);
		if( po.className != null ) {
			o.writeString(po.className);
			o.writeByte(0);
		}
		if( po.cid != null ) o.writeUInt16(po.cid);
		if( po.matrix != null ) writeMatrix(po.matrix);
		if( po.color != null ) writeCXA(po.color);
		if( po.ratio != null ) o.writeUInt16(po.ratio);
		if( po.instanceName != null ) {
			o.writeString(po.instanceName);
			o.writeByte(0);
		}
		if( po.clipDepth != null ) o.writeUInt16(po.clipDepth);
		if( po.filters != null ) writeFilters(po.filters);
		if( po.blendMode != null ) writeBlendMode(po.blendMode);
		if( po.bitmapCache != null ) o.writeByte(po.bitmapCache);
		if( po.events != null ) writeClipEvents(po.events);
	}

	inline function writeInt( v : Int ) {
		#if haxe3
		o.writeInt32(v);
		#else
		o.writeUInt30(v);
		#end
	}

	function writeTID( id : Int, len : Int ) {
		var h = (id << 6);
		if( len < 63 )
			o.writeUInt16(h|len);
		else {
			o.writeUInt16(h|63);
			writeInt(len);
		}
	}

	function writeTIDExt( id : Int, len : Int ) {
		o.writeUInt16((id << 6)|63);
		writeInt(len);
	}

	function writeSound( s : Sound ) {
		var len = 7 + switch( s.data ) {
			case SDMp3(_,data): data.length + 2;
			case SDOther(data): data.length;
		};
		writeTIDExt(TagId.DefineSound, len);
		o.writeUInt16(s.sid);
		bits.writeBits(4, switch( s.format ) {
			case SFNativeEndianUncompressed: 0;
			case SFADPCM: 1;
			case SFMP3: 2;
			case SFLittleEndianUncompressed: 3;
			case SFNellymoser16k: 4;
			case SFNellymoser8k: 5;
			case SFNellymoser: 6;
			case SFSpeex: 11;
		});
		bits.writeBits(2, switch( s.rate ) {
			case SR5k: 0;
			case SR11k: 1;
			case SR22k: 2;
			case SR44k: 3;
		});
		bits.writeBit(s.is16bit);
		bits.writeBit(s.isStereo);
		bits.flush();
		o.writeInt32(s.samples);
		switch( s.data ) {
		case SDMp3(seek,data):
			o.writeInt16(seek);
			o.write(data);
		case SDOther(data):
			o.write(data);
		};
	}

	function writeDefineText( dt : DefineText, v2 : Bool ) {
		o.writeUInt16(dt.cid);
		writeRect(dt.textBounds);
		writeMatrix(dt.textMatrix);
		o.writeByte(dt.glyphBits);
		o.writeByte(dt.advanceBits);
		for ( tr in dt.textRecords ) {
			bits.writeBit(true);
			bits.writeBits(3, 0);
			bits.writeBit(tr.fontId != null );
			bits.writeBit(tr.textColor != null);
			bits.writeBit(tr.yOffset != null);
			bits.writeBit(tr.xOffset != null);
			bits.flush();
			if ( tr.fontId != null ) {
				o.writeUInt16(tr.fontId);
			}
			if ( tr.textColor != null ) {
				if ( v2 ) {
					writeFixed(tr.textColor);
				} else {
					o.writeUInt24(#if haxe3 tr.textColor #else haxe.Int32.toInt(tr.textColor) #end);
				}
			}
			if ( tr.xOffset != null ) {
				o.writeInt16(tr.xOffset);
			}
			if ( tr.yOffset != null ) {
				o.writeInt16(tr.yOffset);
			}
			if ( tr.textHeight != null ) {
				o.writeUInt16(tr.textHeight);
			}
			o.writeByte(tr.glyphEntries.length);
			for ( entry in tr.glyphEntries ) {
				bits.writeBits(dt.glyphBits, entry.glyphIndex);
				bits.writeBits(dt.advanceBits, entry.glyphAdvance);
			}
			bits.flush();
		}
		o.writeByte(0);
	}
	
	function writeDefineEditText( det : DefineEditText ) {
		o.writeUInt16(det.cid);
		writeRect(det.bounds);
		bits.writeBit(det.initialText != null);
		bits.writeBit(det.wordWrap);
		bits.writeBit(det.multiline);
		bits.writeBit(det.password);
		bits.writeBit(det.readOnly);
		bits.writeBit(det.textColor != null);
		bits.writeBit(det.maxLength != null);
		bits.writeBit(det.fontId != null);
		bits.writeBit(det.fontClass != null);
		bits.writeBit(det.autoSize);
		bits.writeBit(det.align != null);
		bits.writeBit(det.noSelect);
		bits.writeBit(det.border);
		bits.writeBit(det.wasStatic);
		bits.writeBit(det.html);
		bits.writeBit(det.useOutlines);
		bits.flush();
		if (det.fontId != null) {
			o.writeUInt16(det.fontId);
		}
		if (det.fontClass != null) {
			o.writeString(det.fontClass);
			o.writeByte(0);
		}
		if (det.fontHeight != null) {
			o.writeUInt16(det.fontHeight);
		}
		if (det.textColor != null) {
			writeRGBA(det.textColor);
		}
		if (det.maxLength != null) {
			o.writeUInt16(det.maxLength);
		}
		if (det.align != null) {
			o.writeByte(Type.enumIndex(det.align));
		}
		if (det.leftMargin != null) {
			o.writeUInt16(det.leftMargin);
		}
		if (det.rightMargin != null) {
			o.writeUInt16(det.rightMargin);
		}
		if (det.indent != null) {
			o.writeUInt16(det.indent);
		}
		if (det.leading != null) {
			o.writeInt16(det.leading);
		}
		o.writeString(det.variableName);
		o.writeByte(0);
		if (det.initialText != null) {
			o.writeString(det.initialText);
			o.writeByte(0);
		}
	}
	
	public function writeTag( t : SWFTag ) {
		switch( t ) {
		case TUnknown(id,data):
			writeTID(id,data.length);
			o.write(data);

		case TShowFrame:
			writeTID(TagId.ShowFrame,0);

		case TShape(id,ver,data):
			writeTID([
				0,
				TagId.DefineShape,
				TagId.DefineShape2,
				TagId.DefineShape3,
				TagId.DefineShape4,
				][ver],
				data.length + 2
			);
			o.writeUInt16(id);
			o.write(data);

		case TBinaryData(id, data):
			writeTID(TagId.DefineBinaryData, data.length + 6);
			o.writeUInt16(id);
			writeInt(0);
			o.write(data);

		case TBackgroundColor(color):
			writeTID(TagId.SetBackgroundColor,3);
			o.bigEndian = true;
			o.writeUInt24(color);
			o.bigEndian = false;

		case TPlaceObject2(po):
			var t = openTMP();
			writePlaceObject(po,false);
			var bytes = closeTMP(t);
			writeTID(TagId.PlaceObject2,bytes.length);
			o.write(bytes);

		case TPlaceObject3(po):
			var t = openTMP();
			writePlaceObject(po,true);
			var bytes = closeTMP(t);
			writeTID(TagId.PlaceObject3,bytes.length);
			o.write(bytes);

		case TRemoveObject2(depth):
			writeTID(TagId.RemoveObject2,2);
			o.writeUInt16(depth);

		case TFrameLabel(label,anchor):
			var bytes = haxe.io.Bytes.ofString(label);
			writeTID(TagId.FrameLabel,bytes.length + 1 + (anchor?1:0));
			o.write(bytes);
			o.writeByte(0);
			if( anchor ) o.writeByte(1);

		case TExport(exports):
			var size = 2;
			var bytes = new Array();
			for( e in exports ) {
				var b = haxe.io.Bytes.ofString(e.name);
				bytes.push(b);
				size += 2 + b.length + 1;
			}
			writeTID(TagId.ExportAssets, size);
			o.writeUInt16(exports.length);
			var pos = 0;
			for( e in exports ) {
				o.writeUInt16(e.cid);
				o.write(bytes[pos++]);
				o.writeByte(0);
			}

		case TClip(id,frames,tags):
			var t = openTMP();
			for( t in tags )
				writeTag(t);
			var bytes = closeTMP(t);
			writeTID(TagId.DefineSprite,bytes.length + 6);
			o.writeUInt16(id);
			o.writeUInt16(frames);
			o.write(bytes);
			o.writeUInt16(0); // end-tag

		case TDoActions(data):
			writeTID(TagId.DoAction,data.length);
			o.write(data);

		case TDoInitActions(id,data):
			writeTID(TagId.DoInitAction,data.length + 2);
			o.writeUInt16(id);
			o.write(data);

		case TActionScript3(data,ctx):
			if( ctx == null )
				writeTID(TagId.RawABC,data.length);
			else {
				var len = data.length + 4 + ctx.label.length + 1;
				writeTID(TagId.DoABC,len);
				writeInt(ctx.id);
				o.writeString(ctx.label);
				o.writeByte(0);
			}
			o.write(data);

		case TSymbolClass(sl):
			var len = 2;
			for( s in sl )
				len += 2 + s.className.length + 1;
			writeTID(TagId.SymbolClass,len);
			o.writeUInt16(sl.length);
			for( s in sl ) {
				o.writeUInt16(s.cid);
				o.writeString(s.className);
				o.writeByte(0);
			}

		case TSandBox(n):
			writeTID(TagId.FileAttributes,4);
			writeInt(n);

		case TBitsLossless(l):
			var cbits = switch( l.color ) { case CM8Bits(n): n; default: null; };
			writeTIDExt(TagId.DefineBitsLossless,l.data.length + ((cbits != null)?8:7));
			o.writeUInt16(l.cid);
			switch( l.color ) {
			case CM8Bits(_): o.writeByte(3);
			case CM15Bits: o.writeByte(4);
			case CM24Bits: o.writeByte(5);
			default: throw "assert";
			}
			o.writeUInt16(l.width);
			o.writeUInt16(l.height);
			if( cbits != null ) o.writeByte(cbits);
			o.write(l.data);

		case TBitsLossless2(l):
			var cbits = switch( l.color ) { case CM8Bits(n): n; default: null; };
			writeTIDExt(TagId.DefineBitsLossless2,l.data.length + ((cbits != null)?8:7));
			o.writeUInt16(l.cid);
			switch( l.color ) {
			case CM8Bits(_): o.writeByte(3);
			case CM32Bits: o.writeByte(5);
			default: throw "assert";
			}
			o.writeUInt16(l.width);
			o.writeUInt16(l.height);
			if( cbits != null ) o.writeByte(cbits);
			o.write(l.data);

		case TBitsJPEG2(id, data):
			writeTIDExt(TagId.DefineBitsJPEG2, data.length + 2);
			o.writeUInt16(id);
			o.write(data);

		case TBitsJPEG3(id, data, mask):
			writeTIDExt(TagId.DefineBitsJPEG3, data.length + mask.length + 6);
			o.writeUInt16(id);
			writeInt(data.length);
			o.write(data);
			o.write(mask);

		case TSound(data):
			writeSound(data);

		case TMorphShape(id, ver, data):
			writeTID(ver == 1 ? TagId.DefineMorphShape : TagId.DefineMorphShape2, data.length + 2);
			o.writeUInt16(id);
			o.write(data);

		case TDefineText(dt):
			var t = openTMP();
			writeDefineText(dt, false);
			var bytes = closeTMP(t);
			writeTID(TagId.DefineText, bytes.length);
			o.write(bytes);

		case TDefineText2(dt):
			var t = openTMP();
			writeDefineText(dt, true);
			var bytes = closeTMP(t);
			writeTID(TagId.DefineText2, bytes.length);
			o.write(bytes);

		case TDefineEditText(det):
			var t = openTMP();
			writeDefineEditText(det);
			var bytes = closeTMP(t);
			writeTID(TagId.DefineEditText, bytes.length);
			o.write(bytes);

		}
	}

	public function writeEnd() {
		o.writeUInt16(0); // end tag
		var bytes = o.getBytes();
		var size = bytes.length;
		if( compressed ) bytes = format.tools.Deflate.run(bytes);
		#if haxe3
		output.writeInt32(size + 8);
		#else
		output.writeUInt30(size + 8);
		#end
		output.write(bytes);
	}

}
