// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2015 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package starling.extensions.lighting
{
    import flash.geom.Matrix3D;
    import flash.geom.Point;

    import starling.display.Mesh;
    import starling.rendering.MeshEffect;
    import starling.rendering.MeshStyle;
    import starling.rendering.VertexDataFormat;
    import starling.textures.Texture;
    import starling.utils.Color;
    import starling.utils.MatrixUtil;

    public class LightMeshStyle extends MeshStyle
    {
        public static const VERTEX_FORMAT:VertexDataFormat = LightMeshEffect.VERTEX_FORMAT;

        private var _light:LightSource;
        private var _normalTexture:Texture;

        // helpers
        private var sPoint:Point = new Point();
        private var sMatrix:Matrix3D = new Matrix3D();

        public function LightMeshStyle(normalTexture:Texture=null, texture:Texture=null)
        {
            super(texture);
            _normalTexture = normalTexture;
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

        override public function setTexCoords(vertexID:int, u:Number, v:Number):void
        {
            // In this case, it makes sense to simply sync the texture coordinates of the
            // standard texture with those of the normal texture.

            setNormalTexCoords(vertexID, u, v);
            super.setTexCoords(vertexID, u, v);
        }

        override public function copyFrom(meshStyle:MeshStyle):void
        {
            var litMeshStyle:LightMeshStyle = meshStyle as LightMeshStyle;
            if (litMeshStyle)
            {
                _light = litMeshStyle._light;
                _normalTexture = litMeshStyle._normalTexture;
            }
            super.copyFrom(meshStyle);
        }

        override public function canBatchWith(meshStyle:MeshStyle):Boolean
        {
            var litMeshStyle:LightMeshStyle = meshStyle as LightMeshStyle;
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

        override public function createEffect():MeshEffect
        {
            return new LightMeshEffect();
        }

        override public function updateEffect(effect:MeshEffect):void
        {
            var litEffect:LightMeshEffect = effect as LightMeshEffect;
            litEffect.normalTexture = _normalTexture;

            if (_light && _light.stage)
            {
                // when batching, the target is not part of the display list; it's placed
                // in the stage coordinate system, so we can simply use the transformation to the
                // stage, instead.

                if (target.stage)
                    _light.getTransformationMatrix3D(target, sMatrix);
                else
                    _light.getTransformationMatrix3D(null, sMatrix);

                // in the local coordinate system of the light, its source is at [0, 0, 0]!
                MatrixUtil.transformCoords3D(sMatrix, 0, 0, 0, litEffect.lightPosition);

                litEffect.diffuseColor = Color.multiply(_light.color, _light.brightness);
                litEffect.ambientColor = Color.multiply(_light.ambientColor, _light.ambientBrightness);
            }

            super.updateEffect(effect);
        }

        override public function get vertexFormat():VertexDataFormat
        {
            return VERTEX_FORMAT;
        }

        override protected function onTargetAssigned(target:Mesh):void
        {
            var numVertices:int = vertexData.numVertices;

            for (var i:int=0; i<numVertices; ++i)
            {
                getTexCoords(i, sPoint);
                setNormalTexCoords(i, sPoint.x, sPoint.y);
            }
        }

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

        public function get light():LightSource { return _light; }
        public function set light(value:LightSource):void { _light = value; }
    }
}
