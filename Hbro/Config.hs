module Hbro.Config where

-- {{{ Imports
import Hbro.Core
import Hbro.Types
import Hbro.Util 

import qualified Config.Dyre as Dyre

import Control.Monad.Trans(liftIO)

import Graphics.Rendering.Pango.Layout

import Graphics.UI.Gtk.Abstract.Widget
import Graphics.UI.Gtk.Builder
import Graphics.UI.Gtk.Display.Label
import Graphics.UI.Gtk.Gdk.EventM
import Graphics.UI.Gtk.Misc.Adjustment
import Graphics.UI.Gtk.Scrolling.ScrolledWindow
import Graphics.UI.Gtk.WebKit.WebView
import Graphics.UI.Gtk.WebKit.WebSettings

import System.Glib.Signals
-- }}}

-- {{{ Dyre
showError :: Configuration -> String -> Configuration
showError configuration message = configuration { mError = Just message }

hbro :: Configuration -> IO ()
hbro = Dyre.wrapMain Dyre.defaultParams {
    Dyre.projectName  = "hbro",
    Dyre.showError    = showError,
    Dyre.realMain     = realMain,
    Dyre.ghcOpts      = ["-threaded"]
}
-- }}}

-- | Default configuration.
-- Does quite nothing.
defaultConfiguration :: Configuration
defaultConfiguration = Configuration {
    mHomePage    = "https://www.google.com",
    mSocketDir   = "/tmp/",
    mUIFile      = "~/.config/hbro/ui.xml",
    mKeys        = [],
    mWebSettings = webSettingsNew,
    mSetup       = \_ -> return () :: IO (),
    mError       = Nothing
}

-- {{{ Statusbar elements
-- | Display scroll position in status bar.
-- Needs a Label intitled "scroll" from the builder.
statusBarScrollPosition :: Browser -> IO ()
statusBarScrollPosition browser = 
  let
    builder         = mBuilder      (mGUI browser)
    scrollWindow    = mScrollWindow (mGUI browser)
  in do
    scrollLabel     <- builderGetObject builder castToLabel "scroll"

    adjustment <- scrolledWindowGetVAdjustment scrollWindow
    _ <- onValueChanged adjustment $ do
        current <- adjustmentGetValue adjustment
        lower   <- adjustmentGetLower adjustment
        upper   <- adjustmentGetUpper adjustment
        page    <- adjustmentGetPageSize adjustment
        
        case upper-lower-page of
            0 -> labelSetMarkup scrollLabel "ALL"
            x -> labelSetMarkup scrollLabel $ show (round $ current/x*100) ++ "%"
    return ()


-- | Display pressed keys in status bar.
-- Needs a Label intitled "keys" from the builder.
statusBarPressedKeys :: Browser -> IO ()
statusBarPressedKeys browser = 
  let
    builder         = mBuilder      (mGUI browser)
    webView         = mWebView      (mGUI browser)
  in do
    keysLabel       <- builderGetObject builder castToLabel "keys"
    
    _ <- after webView keyPressEvent $ do
        value      <- eventKeyVal
        modifiers  <- eventModifier

        let keyString = keyToString value
        case keyString of 
            Just string -> liftIO $ labelSetMarkup keysLabel $ "<span foreground=\"green\">" ++ show modifiers ++ escapeMarkup string ++ "</span>"
            _           -> return ()

        return False
    return ()


-- | Display load progress in status bar.
-- Needs a Label intitled "progress" from the builder.
statusBarLoadProgress :: Browser -> IO ()
statusBarLoadProgress browser = 
  let
    builder         = mBuilder      (mGUI browser)
    webView         = mWebView      (mGUI browser)
  in do
    progressLabel   <- builderGetObject builder castToLabel "progress"

    _ <- on webView loadStarted $ \_ -> do
        labelSetMarkup progressLabel "<span foreground=\"red\">0%</span>"
    
    _ <- on webView progressChanged $ \progress' ->
        labelSetMarkup progressLabel $ "<span foreground=\"yellow\">" ++ show progress' ++ "%</span>"

    _ <- on webView loadFinished $ \_ -> do
        labelSetMarkup progressLabel "<span foreground=\"green\">100%</span>"

    _ <- on webView loadError $ \_ _ _ -> do
        labelSetMarkup progressLabel "<span foreground=\"red\">ERROR</span>"
        return False
    return ()


-- | Display current URI, or the destination of a hovered link, in the status bar.
-- Needs a Label intitled "uri" from the builder.
statusBarURI :: Browser -> IO ()
statusBarURI browser = 
  let
    builder         = mBuilder      (mGUI browser)
    webView         = mWebView      (mGUI browser)
  in do
    uriLabel        <- builderGetObject builder castToLabel "uri"
    
    _ <- on webView loadCommitted $ \_ -> do
        getUri <- (webViewGetUri webView)
        case getUri of 
            Just uri -> labelSetMarkup uriLabel $ "<span weight=\"bold\" foreground=\"white\">" ++ escapeMarkup uri ++ "</span>"
            _        -> labelSetMarkup uriLabel "<span weight=\"bold\" foreground=\"red\">ERROR</span>"

    _ <- on webView hoveringOverLink $ \title hoveredUri -> do
        getUri <- (webViewGetUri webView)
        case (hoveredUri, getUri) of
            (Just u, _) -> labelSetMarkup uriLabel $ "<span foreground=\"#5555ff\">" ++ escapeMarkup u ++ "</span>"
            (_, Just u) -> labelSetMarkup uriLabel $ "<span foreground=\"white\" weight=\"bold\">" ++ escapeMarkup u ++ "</span>"
            _           -> putStrLn "FIXME"
    return ()
-- }}}
