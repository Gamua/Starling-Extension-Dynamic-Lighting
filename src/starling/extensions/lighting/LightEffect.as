// =================================================================================================
//
//	Starling Framework
//	Copyright Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.extensions.lighting
{
    import flash.display3D.Context3D;
    import flash.display3D.Context3DProgramType;
    import flash.geom.Vector3D;

    import starling.rendering.MeshEffect;
    import starling.rendering.Program;
    import starling.rendering.VertexDataFormat;
    import starling.textures.Texture;
    import starling.utils.Color;
    import starling.utils.MathUtil;
    import starling.utils.RenderUtil;

    /** @private */
    public class LightEffect extends MeshEffect
    {
        public static const VERTEX_FORMAT:VertexDataFormat =
            MeshEffect.VERTEX_FORMAT.extend(
                "normalTexCoords:float2, material:bytes4, xAxis:float2, yAxis:float2, zScale:float1");

        private var _lights:Vector.<Light>;
        private var _normalTexture:Texture;
        private var _cameraPosition:Vector3D;

        private static const sVector:Vector.<Number> = new Vector.<Number>(4, true);

        public function LightEffect()
        {
            _lights = new <Light>[];
            _cameraPosition = new Vector3D();
        }

        override protected function createProgram():Program
        {
            var vertexShader:Array = [
                "mov vt0, va4",            // restore actual shininess value ...
                "mul vt0.w, vt0.w, vc5.w", // ... by multiplying with 'MAX_SHININESS'

                "m44  op, va0, vc0",       // transform vertex position into clip space
                "mov  v0, va0     ",       // pass vertex position to FB
                "mov  v1, va1     ",       // pass texture coordinates to FP
                "mul  v2, va2, vc4",       // pass vertex color * vertex alpha to FP
                "mov  v3, va3     ",       // pass normal texture coordinates to FP
                "mov  v4, vt0     ",       // pass material to FP

                "crs vt1.xyz, va5.xyz, va6.xyz",  // calculate local z-axis
                "mul vt1.xyz, vt1.xyz, va7.xxx",  // (possibly) flip local z-axis

                "mov v5.xw, va5.xw",  // vertices va5, va6, vt1 contain the basis vectors of the
                "mov v6.xw, va5.yw",  // local coordinate system. By storing them transposed in
                "mov v7.xw, va5.zw",  // the matrix v5-v7, we'll be able to do a simple matrix
                "mov v5.y, va6.x",    // transform in the fragment shader to get the
                "mov v6.y, va6.y",    // normal vectors into the local coordinate system.
                "mov v7.y, va6.z",
                "mov v5.z, vt1.x",
                "mov v6.z, vt1.y",
                "mov v7.z, vt1.z"
            ];

            // v0 - vertex position
            // v1 - vertex color * vertex alpha
            // v2 - texture coords
            // v3 - normal texture coords
            // v4 - material (ambient, diffuse, specular, shininess)
            // v5-v7 - basis matrix of local coordinate system

            // Note: the vectors stored in the normal maps use a different coordinate system:
            // y goes up and z points towards the camera. This is fixed in the fragment shader!

            var fragmentShader:Array = [
                tex("ft0", "v1", 0, texture),
                "mul ft0, ft0, v2"       // texel color * vertex color     ft0 = surface color
            ];

            if (_normalTexture)
                fragmentShader.push(
                    tex("ft1", "v3", 1, normalTexture, false),
                    "mul ft1.xy, ft1.xy, fc2.xy", // N.xy *= 2
                    "sub ft1.xy, ft1.xy, fc1.xy", // N.xy -= 1
                    "neg ft1.z, ft1.z",           // fix direction of z axis
                    "neg ft1.y, ft1.y"            // fix direction of y axis
                );
            else // use default normal vector
                fragmentShader.push(
                    "mov ft1.xy, fc0.xy",
                    "mov ft1.zw, fc1.zw",
                    "neg ft1.z,  ft1.z"       // N = (0, 0, -1)
                );

            fragmentShader.push(
                "m33 ft1.xyz, ft1.xyz, v5",   // move N into local coords
                "nrm ft1.xyz, ft1.xyz"        // normalize N               ft1 = normal vector
            );

            var numLights:int = MathUtil.min(_lights.length, LightStyle.MAX_NUM_LIGHTS);

            for (var i:int=0; i < numLights; ++i)
            {
                var light:Light = _lights[i];
                var lPos:String = "fc" + (10 + 2*i);
                var lCol:String = "fc" + (11 + 2*i);

                if (light.type == LightSource.TYPE_AMBIENT)
                {
                    fragmentShader.push(
                        "mul ft2, ft0, " + lCol, // illumination = surface color * ambient color
                        "mul ft2, ft2, v4.xxxx"  // illumination *= ambient ratio
                    );
                }
                else
                {
                    var calcLightVector:String = light.type == LightSource.TYPE_POINT ?
                        "sub ft2, " + lPos + ", v0" :
                        "mov ft2, " + lPos;

                    fragmentShader.push(
                        // --- calculate L . N ---
                        calcLightVector,
                        "nrm ft2.xyz, ft2.xyz",   // normalize light vector          ft2 = L
                        "dp3 ft3, ft2, ft1",      //                                 ft3 = L.N
                        "sat ft3, ft3",           // clamp to 0-1

                        // --- calculate R . V ---
                        "mul ft4, ft3, fc2",      // ft4  = (L.N) * 2
                        "mul ft4, ft4, ft1",      // ft4 *= N
                        "sub ft4, ft4, ft2",      // ft4 -= L                        ft4 = R
                        "sub ft5, fc3, v0",       // calculate view vector
                        "nrm ft5.xyz, ft5.xyz",   // normalize view vector           ft5 = V
                        "dp3 ft2, ft4, ft5",      //                                 ft2 = R.V
                        "sat ft2, ft2",           // clamp to 0-1

                        // --- calculate diffuse color ---
                        "mul ft3, ft3, " + lCol,  // diffuse color = (L.N) * light color
                        "mul ft3, ft3, v4.yyyy",  // diffuse color *= diffuse ratio

                        // --- calculate specular color ---
                        "pow ft4, ft2, v4.wwww",  // apply shininess
                        "mul ft4, ft4, " + lCol,  // specular color = (L.N)^shininess * light color
                        "mul ft4, ft4, v4.zzzz",  // specular color *= specular ratio
                        "mul ft4, ft4, ft0.wwww", // premultiply alpha

                        // --- calculate total illumination from this light ---
                        "mul ft2, ft0, ft3" ,    // illumination = surface color * diffuse color
                        "add ft2, ft2, ft4"      // illumination += specular color
                    );
                }

                fragmentShader.push(
                    i == 0 ? "mov ft6, ft2" :
                             "add ft6, ft6, ft2" // final color += illumination
                );
            }

            if (numLights == 0)
                fragmentShader.push("mov ft6, fc0");

            fragmentShader.push(
                "mov ft6.w, ft0.w",      // restore alpha
                "mov oc, ft6"
            );

            return Program.fromSource(vertexShader.join("\n"), fragmentShader.join("\n"));
        }

        override protected function beforeDraw(context:Context3D):void
        {
            super.beforeDraw(context);

            // vc0-vc3 — MVP matrix
            // vc4 — alpha value (same value for all components)
            // vc5 - max shininess

            // fc0 - [0, 0, 0, 0]
            // fc1 - [1, 1, 1, 1]
            // fc2 - [2, 2, 2, 2]
            // fc3 - camera position

            // fc10 - light 0, position
            // fc11 - light 0, color
            // fc12 - light 1, position
            // fc13 - light 1, color
            // ...

            // va0 — vertex position (xy)
            // va1 — texture coordinates
            // va2 — vertex color (rgba), using premultiplied alpha
            // va3 - normal texture coordinates
            // va4 - material (ambientRatio, diffuseRatio, specularRatio, shininess)
            // va5 - x-axis vector (xy)
            // va6 - y-axis vector (xy)
            // va7 - z-axis scale (x) - either '1' or '-1', to flip the z-axis if necessary

            // fs0 — texture
            // fs1 - normal texture

            sVector[0] = sVector[1] = sVector[2] = sVector[3] = LightStyle.MAX_SHININESS;
            context.setProgramConstantsFromVector(Context3DProgramType.VERTEX, 5, sVector);

            sVector[0] = sVector[1] = sVector[2] = sVector[3] = 0.0;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 0, sVector);

            sVector[0] = sVector[1] = sVector[2] = sVector[3] = 1.0;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 1, sVector);

            sVector[0] = sVector[1] = sVector[2] = sVector[3] = 2.0;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 2, sVector);

            sVector[0] = _cameraPosition.x; sVector[1] = _cameraPosition.y;
            sVector[2] = _cameraPosition.z; sVector[3] = _cameraPosition.w;
            context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 3, sVector);

            for (var i:int=0, len:int=_lights.length; i<len; ++i)
            {
                var light:Light = _lights[i];

                sVector[0] = light.x; sVector[1] = light.y; sVector[2] = light.z; sVector[3] = 1.0;
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 10 + 2*i, sVector);

                Color.toVector(light.color, sVector);
                context.setProgramConstantsFromVector(Context3DProgramType.FRAGMENT, 11 + 2*i, sVector);
            }

            if (_normalTexture)
            {
                var repeat:Boolean = textureRepeat && _normalTexture.root.isPotTexture;
                RenderUtil.setSamplerStateAt(1, _normalTexture.mipMapping, textureSmoothing, repeat);
                context.setTextureAt(1, _normalTexture.base);
            }

            vertexFormat.setVertexBufferAt(3, vertexBuffer, "normalTexCoords");
            vertexFormat.setVertexBufferAt(4, vertexBuffer, "material");
            vertexFormat.setVertexBufferAt(5, vertexBuffer, "xAxis");
            vertexFormat.setVertexBufferAt(6, vertexBuffer, "yAxis");
            vertexFormat.setVertexBufferAt(7, vertexBuffer, "zScale");
        }

        override protected function afterDraw(context:Context3D):void
        {
            context.setTextureAt(1, null);
            context.setVertexBufferAt(3, null);
            context.setVertexBufferAt(4, null);
            context.setVertexBufferAt(5, null);
            context.setVertexBufferAt(6, null);
            context.setVertexBufferAt(7, null);

            super.afterDraw(context);
        }

        override protected function get programVariantName():uint
        {
            var normalMapBits:uint = RenderUtil.getTextureVariantBits(_normalTexture);
            var numLights:int = _lights.length;
            var lightBits:uint = 0;

            for (var i:int=0; i<numLights; ++i)
            {
                var light:Light = _lights[i];
                var lightBit:uint;

                switch (light.type)
                {
                    case LightSource.TYPE_AMBIENT: lightBit = 3; break;
                    case LightSource.TYPE_DIRECTIONAL: lightBit = 2; break;
                    default: lightBit = 1;
                }

                lightBits |= lightBit << (i * 2)
            }

            return super.programVariantName | (normalMapBits << 8) | (lightBits << 16);
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }

        public function get numLights():int { return _lights.length; }
        public function set numLights(value:int):void
        {
            var oldNumLights:int = _lights.length;

            for (var i:int=oldNumLights; i<value; ++i)
                _lights[i] = new Light();

            _lights.length = value;
        }

        public function setLightAt(index:int, type:String, color:uint,
                                   positionOrDirection:Vector3D):void
        {
            if (index >= numLights) numLights = index + 1;

            var light:Light = _lights[index];
            light.type = type;
            light.color = color;
            light.x = positionOrDirection.x;
            light.y = positionOrDirection.y;
            light.z = positionOrDirection.z;
        }

        /** The position of the camere in the local coordinate system of the rendered object. */
        public function get cameraPosition():Vector3D { return _cameraPosition; }
        public function set cameraPosition(value:Vector3D):void
        {
            _cameraPosition.copyFrom(value);
        }

        public function get normalTexture():Texture { return _normalTexture; }
        public function set normalTexture(value:Texture):void { _normalTexture = value; }
    }
}

class Light
{
    public var x:Number;
    public var y:Number;
    public var z:Number;
    public var color:uint;
    public var type:String;

    public function Light(color:uint=0xffffff, type="point")
    {
        x = y = z = 0.0;
        this.color = color;
        this.type = type;
    }
}
