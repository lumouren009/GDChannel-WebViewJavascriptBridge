Pod::Spec.new do |s|
  s.name         = 'GDChannel+WebViewJavascriptBridge'
  s.version      = '5.0.5'
  s.summary      = 'An iOS/OSX bridge for sending messages between Obj-C and JavaScript in UIWebViews/WebViews.'
  s.homepage     = 'https://github.com/goodow/GDChannel-WebViewJavascriptBridge'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { 'larrytin' => 'dev@goodow.com' }
  s.requires_arc = true
  s.source       = { :git => 'https://github.com/goodow/GDChannel-WebViewJavascriptBridge.git', :tag => 'v'+s.version.to_s }
  s.platforms = { :ios => "5.0", :osx => "" }
  s.ios.source_files = 'WebViewJavascriptBridge/*.{h,m}'
  s.osx.source_files = 'WebViewJavascriptBridge/*.{h,m}'
  s.ios.private_header_files = 'WebViewJavascriptBridge/WebViewJavascriptBridge_JS.h'
  s.osx.private_header_files = 'WebViewJavascriptBridge/WebViewJavascriptBridge_JS.h'
  s.ios.framework    = 'UIKit'
  s.osx.framework    = 'WebKit'

  s.dependency 'GDChannel', '~> 0.6'
  s.dependency 'NJKWebViewProgress', '~> 0.2'
  s.resources = ['WebViewJavascriptBridge/*.xib']
end
