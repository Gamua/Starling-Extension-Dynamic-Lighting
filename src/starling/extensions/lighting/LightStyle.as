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
    import flash.geom.Matrix;
    import flash.geom.Matrix3D;
    import flash.geom.Point;
    import flash.geom.Vector3D;

    import starling.core.Starling;
    import starling.display.Mesh;
    import starling.display.Stage;
    import starling.rendering.MeshEffect;
    import starling.rendering.RenderState;
    import starling.rendering.VertexData;
    import starling.rendering.VertexDataFormat;
    import starling.styles.MeshStyle;
    import starling.textures.Texture;
    import starling.utils.Color;
    import starling.utils.MatrixUtil;

    /** A mesh style that uses a normal map for dynamic, realistic lighting effects.
     *
     *  <p>Dynamic lighting requires information in which direction a pixel is facing. The
     *  direction information — encoded into a color value — is called a normal map. Normal
     *  maps can be created directly from a 3D program, or drawn on top of 2D objects with
     *  tools like <a href="https://www.codeandweb.com/spriteilluminator">SpriteIlluminator</a>.
     *  </p>
     *
     *  <p>The LightStyle class allows you to attach such a normal map to any Starling mesh.
     *  Furthermore, you can configure the material of the object, e.g. the amount of light
     *  it reflects. Beware that objects are invisible (i.e., black) until you add at least
     *  one light source to the stage!</p>
     *
     *  @see LightSource
     */
    public class LightStyle extends MeshStyle
    {
        public static const VERTEX_FORMAT:VertexDataFormat = LightEffect.VERTEX_FORMAT;

        /** The highest supported value for 'shininess'. */
        public static const MAX_SHININESS:int = 32;

        /** The maximum number of light sources that may be used. */
        public static const MAX_NUM_LIGHTS:int = 8;

        private var _normalTexture:Texture;
        private var _material:Material;

        // helpers
        private var sPoint:Point = new Point();
        private var sPoint3D:Vector3D = new Vector3D();
        private var sMatrix:Matrix = new Matrix();
        private var sMatrix3D:Matrix3D = new Matrix3D();
        private var sMatrixAlt3D:Matrix3D = new Matrix3D();
        private var sMaterial:Material = new Material();
        private var sLights:Vector.<LightSource> = new <LightSource>[];

        /** Creates a new instance with the given normal texture. */
        public function LightStyle(normalTexture:Texture=null)
        {
            _normalTexture = normalTexture;
            _material = new Material();
        }

        /** Sets the texture coordinates of the specified vertex within the normal texture
         *  to the given values. */
        private function setNormalTexCoords(vertexID:int, u:Number, v:Number):void
        {
            if (_normalTexture)
                _normalTexture.setTexCoords(vertexData, vertexID, "normalTexCoords", u, v);
            else
                vertexData.setPoint(vertexID, "normalTexCoords", u, v);

            setRequiresRedraw();
        }

        /** @private */
        override public function setTexCoords(vertexID:int, u:Number, v:Number):void
        {
            // In this case, it makes sense to simply sync the texture coordinates of the
            // standard texture with those of the normal texture.

            setNormalTexCoords(vertexID, u, v);
            super.setTexCoords(vertexID, u, v);
        }

        /** @private */
        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var litMeshStyle:LightStyle = meshStyle as LightStyle;
            if (litMeshStyle)
            {
                _normalTexture = litMeshStyle._normalTexture;
                _material.copyFrom(litMeshStyle._material);
            }
            super.copyFrom(meshStyle);
        }

        /** @private */
        override public function batchVertexData(targetStyle:MeshStyle, targetVertexID:int = 0,
                                                 matrix:Matrix = null, vertexID:int = 0,
                                                 numVertices:int = -1):void
        {
            super.batchVertexData(targetStyle, targetVertexID, matrix, vertexID, numVertices);

            if (matrix)
            {
                // when the mesh is transformed, the directions of the normal vectors must change,
                // too. To be able to rotate them correctly in the shaders, we store the direction
                // of x- and y-axis in the vertex data. (The z-axis is the cross product of x & y.)

                var targetLightStyle:LightStyle = targetStyle as LightStyle;
                var targetVertexData:VertexData = targetLightStyle.vertexData;

                sMatrix.setTo(matrix.a, matrix.b, matrix.c, matrix.d, 0, 0);
                vertexData.copyAttributeTo(targetVertexData, targetVertexID, "xAxis", sMatrix, vertexID, numVertices);
                vertexData.copyAttributeTo(targetVertexData, targetVertexID, "yAxis", sMatrix, vertexID, numVertices);

                if (matrix.a * matrix.d < 0)
                {
                    // When we end up here, the mesh has been flipped horizontally or vertically.
                    // Unfortunately, this makes the local z-axis point into the screen, which
                    // means we're now looking at the object from behind, and it becomes dark.
                    // We reverse this effect manually via the "zScale" vertex attribute.

                    if (numVertices < 0)
                        numVertices = vertexData.numVertices - vertexID;

                    for (var i:int=0; i<numVertices; ++i)
                    {
                        var zScale:Number = vertexData.getFloat(vertexID + i, "zScale");
                        targetVertexData.setFloat(targetVertexID + i, "zScale", zScale * -1);
                    }
                }
            }
        }

        /** @private */
        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            var litMeshStyle:LightStyle = meshStyle as LightStyle;
            if (litMeshStyle && super.canBatchWith(meshStyle))
            {
                var newNormalTexture:Texture = litMeshStyle._normalTexture;

                if (_normalTexture == null && newNormalTexture == null)
                    return true;
                else if (_normalTexture && newNormalTexture)
                    return _normalTexture.base == newNormalTexture.base;
                else
                    return false;
            }
            else return false;
        }

        /** @private */
        override public function createEffect():MeshEffect
        {
            return new LightEffect();
        }

        /** @private */
        override public function updateEffect(effect:MeshEffect, state:RenderState):void
        {
            var lightEffect:LightEffect = effect as LightEffect;
            lightEffect.normalTexture = _normalTexture;

            var stage:Stage = target.stage || Starling.current.stage;
            var lights:Vector.<LightSource> = LightSource.getActiveInstances(stage, sLights);
            lightEffect.numLights = lights.length;

            // get transformation matrix from the stage to the current coordinate system
            if (state.is3D) sMatrixAlt3D.copyFrom(state.modelviewMatrix3D);
            else MatrixUtil.convertTo3D(state.modelviewMatrix, sMatrixAlt3D);
            sMatrixAlt3D.invert();

            // update camera position
            sPoint3D.copyFrom(stage.cameraPosition);
            MatrixUtil.transformPoint3D(sMatrixAlt3D, sPoint3D, lightEffect.cameraPosition);
            
            for (var i:int=0; i<lights.length; ++i)
            {
                var light:LightSource = lights[i];
                var lightColor:uint = Color.multiply(light.color, light.brightness);
                var lightPosOrDir:Vector3D;

                // get transformation matrix from the light to the current coordinate system
                light.getTransformationMatrix3D(null, sMatrix3D);
                sMatrix3D.append(sMatrixAlt3D);

                if (light.type == LightSource.TYPE_POINT)
                    lightPosOrDir = MatrixUtil.transformCoords3D(sMatrix3D, 0, 0, 0, sPoint3D);
                else // type = directional
                {
                    // we're only interested in the rotation, so we wipe out any translations
                    sPoint3D.setTo(0, 0, 0);
                    sMatrix3D.copyColumnFrom(3, sPoint3D);
                    lightPosOrDir = MatrixUtil.transformCoords3D(sMatrix3D, -1, 0, 0, sPoint3D);
                }
                
                // update light properties
                lightEffect.setLightAt(i, light.type, lightColor, lightPosOrDir);
            }

            super.updateEffect(effect, state);
        }

        /** @private */
        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }

        /** @private */
        override protected function onTargetAssigned(target:Mesh):void
        {
            var numVertices:int = vertexData.numVertices;

            for (var i:int=0; i<numVertices; ++i)
            {
                getTexCoords(i, sPoint);
                setNormalTexCoords(i, sPoint.x, sPoint.y);
                setVertexMaterial(i, _material);
                vertexData.setPoint(i, "xAxis", 1, 0);
                vertexData.setPoint(i, "yAxis", 0, 1);
                vertexData.setFloat(i, "zScale", 1);
            }
        }

        /** The texture encoding the surface normals. */
        public function get normalTexture():Texture { return _normalTexture; }
        public function set normalTexture(value:Texture):void
        {
            if (value != _normalTexture)
            {
                if (target)
                {
                    for (var i:int = 0; i < vertexData.numVertices; ++i)
                    {
                        getTexCoords(i, sPoint);
                        if (value) value.setTexCoords(vertexData, i, "normalTexCoords", sPoint.x, sPoint.y);
                    }
                }

                _normalTexture = value;
                setRequiresRedraw();
            }
        }

        private function setVertexMaterial(vertexID:int, material:Material):void
        {
            vertexData.setUnsignedInt(vertexID, "material", material.encode());
            setRequiresRedraw();
        }

        private function getVertexMaterial(vertexID:int, out:Material=null):Material
        {
            if (out == null) out = new Material();
            out.decode(vertexData.getUnsignedInt(vertexID, "material"));
            return out;
        }

        /** Returns the amount of ambient light reflected by the surface around the given vertex.
         *  As a rule of thumb, ambient and diffuse ratio should sum up to '1'. @default 0.5 */
        public function getAmbientRatio(vertexID:int):Number
        {
            return getVertexMaterial(vertexID).ambientRatio;
        }

        /** Assigns the amount of ambient light reflected by the surface around the given vertex.
         *  As a rule of thumb, ambient and diffuse ratio should sum up to '1'. */
        public function setAmbientRatio(vertexID:int, value:Number):void
        {
            getVertexMaterial(vertexID, sMaterial);

            if (sMaterial.ambientRatio != value)
            {
                sMaterial.ambientRatio = value;
                setVertexMaterial(vertexID, sMaterial);
            }
        }

        /** Returns the amount of diffuse light reflected by the surface around the given vertex.
         *  As a rule of thumb, ambient and diffuse ratio should sum up to '1'. @default 0.5 */
        public function getDiffuseRatio(vertexID:int):Number
        {
            return getVertexMaterial(vertexID).diffuseRatio;
        }

        /** Assigns the amount of diffuse light reflected by the surface around the given vertex.
         *  As a rule of thumb, ambient and diffuse ratio should sum up to '1'. */
        public function setDiffuseRatio(vertexID:int, value:Number):void
        {
            getVertexMaterial(vertexID, sMaterial);

            if (sMaterial.diffuseRatio != value)
            {
                sMaterial.diffuseRatio = value;
                setVertexMaterial(vertexID, sMaterial);
            }
        }

        /** Returns the amount of specular light reflected by the surface around the given vertex.
         *  @default 0.1 */
        public function getSpecularRatio(vertexID:int):Number
        {
            return getVertexMaterial(vertexID).specularRatio;
        }

        /** Assigns the amount of specular light reflected by the surface around the given vertex.
         */
        public function setSpecularRatio(vertexID:int, value:Number):void
        {
            getVertexMaterial(vertexID, sMaterial);

            if (sMaterial.specularRatio != value)
            {
                sMaterial.specularRatio = value;
                setVertexMaterial(vertexID, sMaterial);
            }
        }

        /** Shininess is larger for surfaces that are smooth and mirror-like. When this value
         *  is large the specular highlight is small. Range: 0 - 32 @default 1.0 */
        public function getShininess(vertexID:int):Number
        {
            return getVertexMaterial(vertexID).shininess;
        }

        /** Shininess is larger for surfaces that are smooth and mirror-like. When this value
         *  is large the specular highlight is small. Range: 0 - 32 @default 1.0 */
        public function setShininess(vertexID:int, value:Number):void
        {
            getVertexMaterial(vertexID, sMaterial);

            if (sMaterial.shininess != value)
            {
                sMaterial.shininess = value;
                setVertexMaterial(vertexID, sMaterial);
            }
        }

        /** The amount of ambient light reflected by the surface. As a rule of thumb, ambient
         *  and diffuse ratio should sum up to '1'. @default 0.5 */
        public function get ambientRatio():Number { return getAmbientRatio(0); }
        public function set ambientRatio(value:Number):void
        {
            _material.ambientRatio = value;
            
            if (vertexData)
            {
                for (var i:int=0, len:int=vertexData.numVertices; i<len; ++i)
                    setAmbientRatio(i, value);
            }
        }

        /** The amount of diffuse light reflected by the surface. As a rule of thumb, ambient
         *  and diffuse ratio should sum up to '1'. @default 0.5 */
        public function get diffuseRatio():Number { return getDiffuseRatio(0); }
        public function set diffuseRatio(value:Number):void
        {
            _material.diffuseRatio = value;
            
            if (vertexData)
            {
                for (var i:int=0, len:int=vertexData.numVertices; i<len; ++i)
                    setDiffuseRatio(i, value);
            }
        }

        /** The amount of specular light reflected by the surface. @default 0.1 */
        public function get specularRatio():Number { return getSpecularRatio(0); }
        public function set specularRatio(value:Number):void
        {
            _material.specularRatio = value;
            
            if (vertexData)
            {
                for (var i:int=0, len:int=vertexData.numVertices; i<len; ++i)
                    setSpecularRatio(i, value);
            }
        }

        /** Shininess is larger for surfaces that are smooth and mirror-like. When this value
         *  is large the specular highlight is small. Range: 0 - 32 @default 1.0 */
        public function get shininess():Number { return getShininess(0); }
        public function set shininess(value:Number):void
        {
            _material.shininess = value;
            
            if (vertexData)
            {
                for (var i:int=0, len:int=vertexData.numVertices; i<len; ++i)
                    setShininess(i, value);
            }
        }
    }
}

import starling.extensions.lighting.LightStyle;
import starling.utils.MathUtil;

class Material
{
    public var ambientRatio:Number;
    public var diffuseRatio:Number;
    public var specularRatio:Number;
    public var shininess:Number;
    
    public function Material(ambientRatio:Number=0.5, diffuseRatio:Number=0.5, 
                             specularRatio:Number=0.1, shininess:Number=1.0)
    {
        this.ambientRatio = ambientRatio;
        this.diffuseRatio = diffuseRatio;
        this.specularRatio = specularRatio;
        this.shininess = shininess;
    }
    
    public function copyFrom(material:Material):void
    {
        ambientRatio = material.ambientRatio;
        diffuseRatio = material.diffuseRatio;
        specularRatio = material.specularRatio;
        shininess = material.shininess;
    }

    public function decode(encoded:uint):void
    {
        ambientRatio  = ( encoded        & 0xff) / 255.0;
        diffuseRatio  = ((encoded >> 8)  & 0xff) / 255.0;
        specularRatio = ((encoded >> 16) & 0xff) / 255.0;
        shininess     = ((encoded >> 24) & 0xff) / 255.0 * LightStyle.MAX_SHININESS;
    }

    public function encode():uint
    {
        // all other material ratios are between 0 and 1; shininess, however, goes up to
        // MAX_SHININESS. We store its ratio relative to the maximum and restore the actual
        // value in "decode" and in the vertex shader.
        
        const S:Number = LightStyle.MAX_SHININESS;
        
        var amb:uint = MathUtil.clamp(ambientRatio  * 255, 0, 255);
        var dif:uint = MathUtil.clamp(diffuseRatio  * 255, 0, 255);
        var spe:uint = MathUtil.clamp(specularRatio * 255, 0, 255);
        var shi:uint = MathUtil.clamp(shininess / S * 255, 0, 255);

        return amb | (dif << 8) | (spe << 16) | (shi << 24);
    }
}