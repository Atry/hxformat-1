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

class Tools {

	public static function signExtend( v : Int, nbits : Int ) {
		var max = 1 << nbits;
		// sign bit is set
		if( v & (max >> 1) != 0 )
			return v - max;
		return v;
	}

	public inline static function floatFixedBits( i : Int, nbits ) {
		i = signExtend(i,nbits);
		return (i >> 16) + (i & 0xFFFF) / 65536.0;
	}

	#if haxe3
	public inline static function floatFixed( i : Int ) {
		return (i >> 16) + (i & 0xFFFF) / 65536.0;
	}
	#else
	public inline static function floatFixed( i : haxe.Int32 ) {
		return haxe.Int32.toInt(haxe.Int32.shr(i,16)) + haxe.Int32.toInt(haxe.Int32.and(i,haxe.Int32.ofInt(0xFFFF))) / 65536.0;
	}
	#end

	public inline static function floatFixed8( i : Int ) {
		return (i >> 8) + (i & 0xFF) / 256.0;
	}

	public inline static function toFixed8( f : Float ) {
		var i = Std.int(f);
		if( ((i>0)?i:-i) >= 128 )
			throw haxe.io.Error.Overflow;
		if( i < 0 ) i = 256-i;
		return (i << 8) | Std.int((f-i)*256.0);
	}

	public static function hex( b : haxe.io.Bytes, ?max : Int ) {
		var hex = ["0".code,"1".code,"2".code,"3".code,"4".code,"5".code,"6".code,"7".code,"8".code,"9".code,"A".code,"B".code,"C".code,"D".code,"E".code,"F".code];
		var count = if( max == null || b.length <= max ) b.length else max;
		var buf = new StringBuf();
		for( i in 0...count ) {
			var v = b.get(i);
			buf.addChar(hex[v>>4]);
			buf.addChar(hex[v&15]);
		}
		if( count < b.length )
			buf.add("...");
		return buf.toString();
	}

	public static function dumpTag( t : SWFTag, ?max : Int ) {
		var infos : Array<Dynamic> = switch( t ) {
		case TShowFrame: [];
		case TBackgroundColor(color): [StringTools.hex(color,6)];
		case TShape(id, version, data): ["id", id, "version", version, "data", hex(data, max)];
		case TMorphShape(id,version,data): ["id",id,"version",version,"data",hex(data,max)];
		case TBinaryData(id,data): ["id",id,"data",hex(data,max)];
		case TClip(id,frames,tags): ["id",id,"frames",frames];
		case TPlaceObject2(po): [Std.string(po)];
		case TPlaceObject3(po): [Std.string(po)];
		case TRemoveObject2(d): ["depth",d];
		case TFrameLabel(label, anchor): ["label", label, "anchor", anchor];
		case TExport(el) :
			var a = new Array<Dynamic>();
			for( e in el ) {
				a.push(e.name);
				a.push(e.cid);
			}
			a;
		case TDoInitActions(id,data): ["id",id,"data",hex(data,max)];
		case TActionScript3(data,context): ["context",context,"data",hex(data,max)];
		case TSymbolClass(symbols): [Std.string(symbols)];
		case TSandBox(v): [v];
		case TBitsLossless(l),TBitsLossless2(l): ["id",l.cid,"color",l.color,"width",l.width,"height",l.height,"data",hex(l.data,max)];
		case TBitsJPEG2(id, data): ["id", id, "data", hex(data,max)];
		case TBitsJPEG3(id, data, mask): ["id", id, "data", hex(data,max), "mask", hex(mask,max)];
		case TSound(s):
			var data = switch( s.data ) {
				case SDMp3(seek,data): "seek="+seek+":"+hex(data,max);
				case SDOther(data): hex(data,max);
			};
			["sid", s.sid, "format", s.format, "rate", s.rate, "16bit", s.is16bit, "stereo", s.isStereo, "samples", s.samples, "data", data ];
		case TDoActions(data) : ["data",hex(data,max)];
		case TUnknown(id,data): ["id",id,"data",hex(data,max)];
		}
		var b = new StringBuf();
		b.add(Type.enumConstructor(t));
		b.add("(");
		while( infos.length > 0 ) {
			b.add(infos.shift());
			if( infos.length == 0 )
				break;
			b.add(":");
			b.add(Std.string(infos.shift()));
			if( infos.length == 0 )
				break;
			b.add(",");
		}
		b.add(")");
		return b.toString();
	}

}
