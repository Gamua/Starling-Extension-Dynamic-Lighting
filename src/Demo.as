// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2015 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package
{
    import starling.core.Starling;
    import starling.display.MovieClip;
    import starling.display.Sprite;
    import starling.events.Event;
    import starling.extensions.lighting.LightMeshStyle;
    import starling.extensions.lighting.LightSource;
    import starling.textures.Texture;
    import starling.textures.TextureAtlas;

    public class Demo extends Sprite
    {
        [Embed(source="../assets/character.png")]
        private static const CharacterTexture:Class;

        [Embed(source="../assets/character_n.png")]
        private static const CharacterNormalTexture:Class;

        [Embed(source="../assets/character.xml", mimeType="application/octet-stream")]
        private static const CharacterXml:Class;

        private var _characters:Vector.<MovieClip>;

        public function Demo()
        {
            var characterTexture:Texture = Texture.fromEmbeddedAsset(CharacterTexture);
            var characterNormalTexture:Texture = Texture.fromEmbeddedAsset(CharacterNormalTexture);
            var characterXml:XML = XML(new CharacterXml());

            var textureAtlas:TextureAtlas = new TextureAtlas(characterTexture, characterXml);
            var normalTextureAtlas:TextureAtlas = new TextureAtlas(characterNormalTexture, characterXml);

            var textures:Vector.<Texture> = textureAtlas.getTextures();
            var normalTextures:Vector.<Texture> = normalTextureAtlas.getTextures();

            var stageWidth:Number = Starling.current.stage.stageWidth;
            var numCharacters:int = 8;
            var characterWidth:Number = textures[0].frameWidth;
            var offset:Number = (stageWidth + characterWidth) / numCharacters;

            var light:LightSource = new LightSource();
            light.x = stageWidth / 2;
            light.y = 50;
            light.z = -200;
            light.brightness = 0.6;
            light.ambientBrightness = 0.4;
            light.showLightBulb = true;

            _characters = new <MovieClip>[];

            for (var i:int=0; i<numCharacters; ++i)
            {
                var movie:MovieClip = createCharacter(textures, normalTextures, light);
                movie.currentTime = movie.totalTime * Math.random();
                movie.x = -characterWidth + i * offset;
                movie.y = -10;
                addChild(movie);
                _characters.push(movie);
            }

            addChild(light);
            addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }

        private function onEnterFrame(event:Event, passedTime:Number):void
        {
            var rightBounds:Number = Starling.current.stage.stageWidth;

            for each (var character:MovieClip in _characters)
            {
                character.advanceTime(passedTime);
                character.x += 100 * passedTime;

                if (character.x > rightBounds)
                    character.x = -character.width;
            }
        }

        private function createCharacter(textures:Vector.<Texture>, normalTextures:Vector.<Texture>,
                                         light:LightSource, fps:int=12):MovieClip
        {
            var movie:MovieClip = new MovieClip(textures, fps);
            var lightStyle:LightMeshStyle = new LightMeshStyle();
            lightStyle.light = light;
            movie.style = lightStyle;

            for (var i:int=0; i<movie.numFrames; ++i)
                movie.setFrameAction(i, updateStyle);

            return movie;

            function updateStyle(movieClip:MovieClip, frameID:int):void
            {
                lightStyle.normalTexture = normalTextures[frameID];
            }
        }
    }
}
