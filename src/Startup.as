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
    import flash.geom.Rectangle;
    import flash.system.Capabilities;

    import starling.core.Starling;
    import starling.utils.SystemUtil;

    [SWF(width="760", height="300", frameRate="60", backgroundColor="#202020")]
    public class Startup extends Sprite
    {
        private var _starling:Starling;

        public function Startup()
        {
            var viewPort:Rectangle = null;

            if (!SystemUtil.isDesktop)
                viewPort = new Rectangle(0, 0, stage.fullScreenWidth, stage.fullScreenHeight);

            _starling = new Starling(Demo, stage, viewPort);
            _starling.enableErrorChecking = Capabilities.isDebugger;
            _starling.skipUnchangedFrames = true;
            _starling.showStats = false;
            _starling.start();
        }
    }
}
