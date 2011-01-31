# ---------------------------------
# Pachube2Sketchup
# ---------------------------------
# Version: 0.2
#
# Plug-in that connects SketchUp Ruby Api with Pachube for 
# serving real-time and historic sensor data into SketchUp
# email: c.burman@haque.co.uk




require 'sketchup.rb'
$values = []
$numFeeds
$sensorArray = []
$pGroup = []
$sensorDef
$xLocs = []
$yLocs = []
$zLocs = []
$logo
$objs = []
$locations = []
$vizObj = []
$minVals = []
$maxVals = []
$sensorNum = 0
$scalersAdded = false

$scalerNum = 0
$scalerLocations = []
$activeEnv
$activeObj = 0
$numActiveObjs = 0
@pachup_window = UI::WebDialog.new("Pachube2SketchUp", false, "PachUp Box", 390, 240, 10, 52, false)
page = "p2s.html"	
html_path = Sketchup.find_support_file page,"Plugins/pachube2sketchup"
@pachup_window.set_file(html_path)
@pachup_window.show()
@pachup_window.bring_to_front


@pachup_window.add_action_callback("setValues") do |web_dialog,values|

$values = values.split(",")
$values.length.times do |i|
if $values[i] != nil && i != 0
puts "Value " + i.to_s + ":  = " + $values[i].to_s 
end
end

$values.length.times do |j|
$values[j] = $values[j].to_f
$values[j] =  ($values[j] * 100).round.to_f / 100
end
scaleVizObjs()

end


@pachup_window.add_action_callback("maxMin") do |web_dialog,values|

maxMin = values.split(",")
$activeEnv.set_attribute $activeObj.to_s, "min", maxMin[0]
$activeEnv.set_attribute $activeObj.to_s, "max", maxMin[1]
puts "Object " + $activeObj.to_s + ".. Max:" + maxMin[0].to_s + "  Min:" + maxMin[1].to_s
puts "Loading History..."
js_data =  "getHistory()"
web_dialog.execute_script(js_data)
end

@pachup_window.add_action_callback("history") do |web_dialog,values|
puts "History Loaded"
$activeObj += 1
getData()
end

@pachup_window.add_action_callback("createEnv") do |web_dialog,values|
createEnv(values)
end

@pachup_window.add_action_callback("addSensor") do |web_dialog,values|

addSensor()
end
@pachup_window.add_action_callback("setSensor") do |web_dialog,values|
puts values
fS = []
fS = values.split(",")
setSensor(fS[0],fS[1])
end
@pachup_window.add_action_callback("addScaler") do |web_dialog,values|
addScalers()
end
@pachup_window.add_action_callback("setScaler") do |web_dialog,values|
setScaler()
end

@pachup_window.add_action_callback("activateEnv") do |web_dialog,values|
activateEnv()
end

def createEnv(label)

#addEnvAtts()
#at some point this function is going to have to be extended

#add logo is the flag
addLogo(label)
#TODO sort out the datum function so that Feeds can be located FROM sketchup
#datum = Sketchup.active_model.get_datum
#puts datum
puts "New Pachube Environment \""+label+"\" created..."
end

def addLogo(label)
model = Sketchup.active_model
logo_path = Sketchup.find_support_file "logo.skp" ,"Plugins/pachube2sketchup"
logo_def = model.definitions.load logo_path
logo_location = Geom::Point3d.new 0,0,0
transform = Geom::Transformation.new logo_location
model = Sketchup.active_model
entities = model.active_entities
$pGroup[0] = entities.add_group
entities = $pGroup[0].entities
instance = entities.add_instance logo_def, transform
entity = instance
entity.make_unique
name = entity.definition.name="PachubeLogo"
entity.definition.description = "This Flag Identifies the Origin of the Pachube Environment"

$pGroup[0].set_attribute "0", "type", "static"
$pGroup[0].set_attribute "0", "transformation", entity.transformation.to_a
$pGroup[0].set_attribute "0", "feedID", 1908
$pGroup[0].set_attribute "0", "streamID", 0
$pGroup[0].set_attribute "0", "objectID", 0
$pGroup[0].set_attribute "0", "entName", entity.definition.name
$pGroup[0].set_attribute "EnvData", "objNum", 1
$pGroup[0].set_attribute "EnvData", "label", 1
$sensorNum = 1


end

def addSensor()
model = Sketchup.active_model
temp_sensor_path = Sketchup.find_support_file "sensor_holder.skp" ,"Plugins/pachube2sketchup"
$sensorDef = model.definitions.load temp_sensor_path
Sketchup.active_model.place_component($sensorDef)
end

def setSensor(feed,stream)
puts "Feed:  " + feed.to_s
puts "Stream:  " + stream.to_s
objNum = $pGroup[0].get_attribute "EnvData", "objNum"
selection = Sketchup.active_model.selection

if selection.length == 1
if selection[0].kind_of?(Sketchup::ComponentInstance) 
entity = selection[0]
entity.make_unique
name = entity.definition.name="pObj"+$sensorNum.to_s
entity.definition.description = "This is Pachube Enabled Component Number: " + $sensorNum.to_s

$sensorArray[objNum] = $pGroup[0].entities.add_instance entity.definition, entity.transformation
if (feed.to_s == '0')
$pGroup[0].set_attribute $sensorNum.to_s, "type", "static"
else
$pGroup[0].set_attribute $sensorNum.to_s, "type", "scaler"
end
$pGroup[0].set_attribute $sensorNum.to_s, "transformation", entity.transformation.to_a
$pGroup[0].set_attribute $sensorNum.to_s, "feedID", feed
$pGroup[0].set_attribute $sensorNum.to_s, "streamID", stream
$pGroup[0].set_attribute $sensorNum.to_s, "objectID", $sensorArray[objNum].to_s
$pGroup[0].set_attribute $sensorNum.to_s, "objectNum", $sensorNum.to_i
$pGroup[0].set_attribute $sensorNum.to_s, "entName", entity.definition.name
entity.erase!
info = $pGroup[0].attribute_dictionary($sensorNum.to_s)
puts info["type"]
puts info["transformation"]
puts info["feedID"]
puts info["objectID"]
puts info["streamID"]
puts info["entName"]
$pGroup[0].set_attribute "EnvData", "objNum", objNum + 1
$sensorNum += 1
else
puts "The object you have selected isn't a Component"
end
elsif selection.length > 1
puts "You have Selected Too Many Objects"
else 
puts "You Need To Select a Component"
end

end

def setScaler()
$scalersAdded = true
selection = Sketchup.active_model.selection
entity = selection[0]
model = Sketchup.active_model
$scalerLocations[$scalerNum] = entity.transformation
entity_def = entity.definition
entity.erase!
$vizObj[$sensorNum] = $pGroup[0].entities.add_instance entity_def, $scalerLocations[$scalerNum]
$scalerNum += 1
end
def loadValues
end
def scaleVizObjs()
$objs.length.times do |c|
info = $activeEnv.attribute_dictionary(c.to_s)
if (info['type'] == 'scaler')
$objs[c].hidden = false
val = $values[c] - info["min"].to_f
range = info["max"].to_f - info["min"].to_f
if range == 0
range = 0.1
end
if val == 0
val = 0.1
end
scale = val / range
tOld = Geom::Transformation.new(info["transformation"])
p = tOld.origin
t = Geom::Transformation.scaling p, 1, 1, scale
$objs[c].transform! $objs[c].transformation.inverse
$objs[c].transform! tOld
$objs[c].transform! t
end
end
end

def addScalers()

counter = 0
$sensorNum.times do
addScaleObj(counter)
counter += 1
end
$scalersAdded = true
end
def addScaleObj(counter)
model = Sketchup.active_model
temp_scale_path = Sketchup.find_support_file "grapher.skp" ,"Plugins/pachube2sketchup"
$scalerDef = model.definitions.load temp_scale_path
$vizObj[counter] = $pGroup[0].entities.add_instance $scalerDef, $locations[counter]
end

def activateEnv()
selection = Sketchup.active_model.selection
if selection.length > 1

puts "You Have Selected Too Many Objects. Please Pick One Pachube Environment"
elsif selection.length < 1

puts "Please Select a Pachube Environment to Activate"
else
if selection[0].kind_of?(Sketchup::Group)
$activeEnv = Sketchup.active_model.selection[0]
$numActiveObjs = $activeEnv.get_attribute "EnvData", "objNum"
if $numActiveObjs == nil
js_errorMsg = "setMsg('outputText','The object you have selected is not a valid Pachube Environment')"
@pachup_window.execute_script(js_errorMsg)


puts "The Object You Have Selected is Not a Valid Pachube Environment"

elsif $numActiveObjs == 0
js_errorMsg = "setMsg('outputText','The Pachube Environment You Have Selected is Empty')"
@pachup_window.execute_script(js_errorMsg)
puts "The Pachube Environment You Have Selected is Empty"
else

readEnv()
puts ""
puts "----------------------"
puts "Matching Entities..."
detectLogo()
$activeEnv.entities.count.times do |j|
setInstance(j)
end
puts "----------------------"
setViz()

$activeObj = 0
getData()

end
else


puts "The Object You Have Selected is Not a Valid Pachube Environment"


end
end

end

def readEnv()
puts "------------------------------"
puts "Reading Pachube Environment..."


envData = $activeEnv.attribute_dictionary("EnvData")
label = envData["label"]

msg = "Active Environment is: " + label.to_s
puts msg

msg2 = "It Contains " +$numActiveObjs.to_s + " Pachube Enabled Components" 
puts msg2



js_errorMsg = "setMsg('outputText','"+msg.to_s+"<br>"+msg2+"<br>Loading Pachube Data...')"
@pachup_window.execute_script(js_errorMsg)



$numActiveObjs.times do |num|
info = $activeEnv.attribute_dictionary(num.to_s)
puts ""
puts "Object " + (num).to_s + ":  "
puts "Type: " + info["type"]
puts "Connected to Pachube Feed: " +info["feedID"].to_s + ", Stream Number:  " + info["streamID"].to_s
#puts info["transformation"]
end
#objNum = $activeEnv.get_attribute "EnvData", "objNum"
end

def getData()
info = $activeEnv.attribute_dictionary($activeObj.to_s)
if $activeObj < $numActiveObjs
if info["type"] == "static"
$activeObj += 1
getData()
else
puts "Loading Object " + $activeObj.to_s + " Data..."
startData(info["feedID"].to_s,info["streamID"].to_s,$activeObj.to_s,$numActiveObjs.to_s)
end
else
puts "---------------"
puts "All Data Loaded"
puts "---------------"

puts "Loading Most Recent Values..."
js_activate =  "setInitialTime()"
@pachup_window.execute_script(js_activate)

end
end

def startData(feedID, streamID, curObj, totObj)
js_dataPOST =  "getJSON(\'"+feedID+"\',\'"+streamID+"\',\'"+curObj+"\',\'"+totObj+"\')"
@pachup_window.execute_script(js_dataPOST)
end
def setInstance(num)
info = $activeEnv.attribute_dictionary(num.to_s)
$activeEnv.entities.count.times do |i|
if info["entName"].to_s == $activeEnv.entities[i].definition.name.to_s
$objs[num] =  $activeEnv.entities[i]
#puts $objs[num].to_s
puts $activeEnv.entities[i].definition.name.to_s + " ...Match Found " 

end
end
end
def detectLogo()
$activeEnv.entities.count.times do |i|
if $activeEnv.entities[i].definition.name.to_s == "PachubeLogo"
$logo = $activeEnv.entities[i]
end
end
puts "Logo Detected"
end

def setViz()
num = $objs.length
num.times do |i|

end
$objs.length.times do |c|
info = $activeEnv.attribute_dictionary((c).to_s)
if (info['type'] == 'scaler')
tOld = Geom::Transformation.new(info["transformation"])
p = tOld.origin
$objs[c].transform! $objs[c].transformation.inverse
$objs[c].transform! tOld
#$objs[c].hidden = true
end
end
end


#$activeEnv.set_attribute "1", "streamID", 0
