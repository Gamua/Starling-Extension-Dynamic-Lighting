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
    import starling.extensions.lighting.LightStyle;
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
        private var _stageWidth:Number;
        private var _stageHeight:Number;

        public function Demo()
        {
            _stageWidth  = Starling.current.stage.stageWidth;
            _stageHeight = Starling.current.stage.stageHeight;
            _characters = new <MovieClip>[];

            var characterTexture:Texture = Texture.fromEmbeddedAsset(CharacterTexture);
            var characterNormalTexture:Texture = Texture.fromEmbeddedAsset(CharacterNormalTexture);
            var characterXml:XML = XML(new CharacterXml());

            var textureAtlas:TextureAtlas = new TextureAtlas(characterTexture, characterXml);
            var normalTextureAtlas:TextureAtlas = new TextureAtlas(characterNormalTexture, characterXml);
            var textures:Vector.<Texture> = textureAtlas.getTextures();
            var normalTextures:Vector.<Texture> = normalTextureAtlas.getTextures();

            var light:LightSource = new LightSource();
            light.x = 380;
            light.y = 50;
            light.z = -150;
            light.brightness = 0.6;
            light.ambientBrightness = 0.4;
            light.showLightBulb = true;

            addMarchingCharacters(8, light, textures, normalTextures);
            addChild(light);
        }

        private function addMarchingCharacters(count:int, light:LightSource,
                                               textures:Vector.<Texture>,
                                               normalTextures:Vector.<Texture>):void
        {
            var characterWidth:Number = textures[0].frameWidth;
            var offset:Number = (_stageWidth + characterWidth) / count;

            for (var i:int=0; i<count; ++i)
            {
                var movie:MovieClip = createCharacter(textures, normalTextures, light);
                movie.currentTime = movie.totalTime * Math.random();
                movie.x = -characterWidth + i * offset;
                movie.y = -10;
                movie.addEventListener(Event.ENTER_FRAME, onEnterFrame);
                addChild(movie);
                _characters.push(movie);
            }

            function onEnterFrame(event:Event, passedTime:Number):void
            {
                var character:MovieClip = event.target as MovieClip;
                character.advanceTime(passedTime);
                character.x += 100 * passedTime;

                if (character.x > _stageWidth)
                    character.x = -character.width + (character.x - _stageWidth);
            }
        }

        /** This method is useful during development, to have a simple static image that's easy
         *  to experiment with. */
        private function addStaticCharacter(light:LightSource, texture:Texture, normalTexture:Texture):void
        {
            var movie:MovieClip = createCharacter(
                    new <Texture>[texture],
                    new <Texture>[normalTexture], light, 1);

            movie.alignPivot();
            movie.x = _stageWidth  / 2 + 0.5;
            movie.y = _stageHeight / 2 + 0.5;
            addChild(movie);
            _characters.push(movie);
        }

        private function createCharacter(textures:Vector.<Texture>, normalTextures:Vector.<Texture>,
                                         light:LightSource, fps:int=12):MovieClip
        {
            var movie:MovieClip = new MovieClip(textures, fps);
            var lightStyle:LightStyle = new LightStyle(normalTextures[0]);
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
