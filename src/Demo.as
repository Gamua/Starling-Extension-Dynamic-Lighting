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
    import flash.geom.Point;

    import starling.core.Starling;
    import starling.display.DisplayObject;
    import starling.display.MovieClip;
    import starling.display.Sprite;
    import starling.display.Sprite3D;
    import starling.events.Event;
    import starling.events.Touch;
    import starling.events.TouchEvent;
    import starling.events.TouchPhase;
    import starling.extensions.lighting.LightSource;
    import starling.extensions.lighting.LightStyle;
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

            var ambientLight:LightSource = LightSource.createAmbientLight();
            ambientLight.x = 380;
            ambientLight.y = 60;
            ambientLight.z = -150;
            ambientLight.showLightBulb = true;

            var pointLightA:LightSource = LightSource.createPointLight(0x00ff00);
            pointLightA.x = 180;
            pointLightA.y = 60;
            pointLightA.z = -150;
            pointLightA.showLightBulb = true;

            var pointLightB:LightSource = LightSource.createPointLight(0xff00ff);
            pointLightB.x = 580;
            pointLightB.y = 60;
            pointLightB.z = -150;
            pointLightB.showLightBulb = true;

            var directionalLight:LightSource = LightSource.createDirectionalLight();
            directionalLight.x = 460;
            directionalLight.y = 100;
            directionalLight.z = -150;
            directionalLight.rotationY = -1.0;
            directionalLight.showLightBulb = true;

            addMarchingCharacters(8, textures, normalTextures);
            // addStaticCharacter(textures[0], normalTextures[0]);

            addChild(ambientLight);
            addChild(pointLightA);
            addChild(pointLightB);
            // addChild(directionalLight);
        }

        private function addMarchingCharacters(count:int,
                                               textures:Vector.<Texture>,
                                               normalTextures:Vector.<Texture>):void
        {
            var characterWidth:Number = textures[0].frameWidth;
            var offset:Number = (_stageWidth + characterWidth) / count;

            for (var i:int=0; i<count; ++i)
            {
                var movie:MovieClip = createCharacter(textures, normalTextures);
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
        private function addStaticCharacter(texture:Texture, normalTexture:Texture):void
        {
            var movie:MovieClip = createCharacter(
                    new <Texture>[texture],
                    new <Texture>[normalTexture], 1);

            movie.alignPivot();
            _characters.push(movie);

            var sprite3D:Sprite3D = new Sprite3D();
            sprite3D.addChild(movie);
            sprite3D.x = _stageWidth  / 2 + 0.5;
            sprite3D.y = _stageHeight / 2 + 0.5;
            addChild(sprite3D);

            var that:DisplayObject = this;

            sprite3D.addEventListener(TouchEvent.TOUCH, function(event:TouchEvent):void
            {
                var touch:Touch = event.getTouch(sprite3D, TouchPhase.MOVED);
                if (touch)
                {
                    var movement:Point = touch.getMovement(that);

                    if (event.shiftKey)
                    {
                        sprite3D.rotationX -= movement.y * 0.01;
                        sprite3D.rotationY += movement.x * 0.01;
                    }
                    else
                    {
                        sprite3D.x += movement.x;
                        sprite3D.y += movement.y;
                    }
                }
            });
        }

        private function createCharacter(textures:Vector.<Texture>,
                                         normalTextures:Vector.<Texture>,
                                         fps:int=12):MovieClip
        {
            var movie:MovieClip = new MovieClip(textures, fps);
            var lightStyle:LightStyle = new LightStyle(normalTextures[0]);
            lightStyle.ambientRatio = 0.3;
            lightStyle.diffuseRatio = 0.7;
            lightStyle.specularRatio = 0.5;
            lightStyle.shininess = 16;
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
