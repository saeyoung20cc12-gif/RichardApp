require 'xcodeproj'
project_path = '/Users/mac/Documents/duck/RichardApp/RichardApp.xcodeproj'
project = Xcodeproj::Project.open(project_path)

app_target = project.targets.find { |t| t.name == 'RichardApp' }
widget_target = project.targets.find { |t| t.name == 'RichardWidgetExtension' }

if widget_target
  files_to_find = ['Assets.xcassets', 'RichardModels.swift', 'RichardActivityAttributes.swift']
  
  files_to_find.each do |filename|
    file_ref = project.files.find { |f| f.path == filename || f.path.to_s.end_with?(filename) || f.name == filename }
    
    if file_ref
      unless widget_target.source_build_phase.files_references.include?(file_ref) || widget_target.resources_build_phase.files_references.include?(file_ref)
        if filename.end_with?('.xcassets')
          widget_target.resources_build_phase.add_file_reference(file_ref)
          puts "Added #{filename} to widget resources"
        else
          widget_target.source_build_phase.add_file_reference(file_ref)
          puts "Added #{filename} to widget sources"
        end
      else
        puts "#{filename} already in widget target"
      end
    else
      puts "Could not find file reference: #{filename}"
    end
  end
end

app_target.build_configurations.each do |config|
  config.build_settings['INFOPLIST_KEY_NSSupportsLiveActivities'] = 'YES'
end

project.save
puts "Successfully applied all fixes!"
