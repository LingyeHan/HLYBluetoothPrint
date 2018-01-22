# Uncomment the next line to define a global platform for your project
# platform :ios, '9.0'
source 'https://github.com/CocoaPods/Specs.git'

platform :ios, '9.0'
#use_frameworks!
inhibit_all_warnings!

def pods
  pod 'HLYBluetoothPrint', :path => '../HLYBluetoothPrint/', :inhibit_warnings => false
end

target 'HLYBluetoothPrintDemo' do
  # Uncomment the next line if you're using Swift or would like to use dynamic frameworks
  # use_frameworks!
  pods
end

target 'HLYBluetoothPrintDemoTests' do
  inherit! :search_paths
  # Pods for testing
end
