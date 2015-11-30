// =================================================================================================
//
//	Starling Framework
//	Copyright 2011-2015 Gamua. All Rights Reserved.
//
//	This program is free software. You can redistribute and/or modify it
//	in accordance with the terms of the accompanying license agreement.
//
// =================================================================================================

package {

    import flash.display.Sprite;

    import starling.core.Starling;

    [SWF(width="760", height="300", frameRate="60", backgroundColor="#202020")]
    public class Startup extends Sprite
    {
        private var _starling:Starling;

        public function Startup()
        {
            _starling = new Starling(Demo, stage);
            _starling.enableErrorChecking = true;
            _starling.showStats = true;
            _starling.start();
        }
    }
}
