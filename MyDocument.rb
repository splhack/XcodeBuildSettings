class MyController < NSObjectController
  attr_writer :tableView, :document

  def load(pbxproj)
    @plist = NSPropertyListSerialization.propertyListFromData(pbxproj,
        mutabilityOption:0, format:nil, errorDescription:nil)
    objects = @plist["objects"]
    @buildSettings = Hash.new
    objects.values.each do |obj|
      key = obj["buildConfigurationList"]
      if key
        productName = obj["productName"] || ""
        @buildSettings[productName] = Hash.new
        list = objects[key]
        list["buildConfigurations"].each do |ckey|
          config = objects[ckey]
          targetName = config["name"]
          @buildSettings[productName][targetName] = config["buildSettings"]
        end
      end
    end
  end

  def save(url)
    puts @plist
  end

  def calcWidth(width, string)
    size = string.sizeWithAttributes(@attribute)
    w = size.width
    w > width ? w : width
  end

  def awakeFromNib
    @document.controller = self
    load(@document.fileWrapper.regularFileContents)

    @tableView.removeTableColumn(@tableView.tableColumns.first)
    index_column = NSTableColumn.new
    index_column.headerCell.setStringValue("")
    @tableView.addTableColumn(index_column)

    font = index_column.dataCell.font
    @attribute = NSMutableDictionary.new
    @attribute[NSFontAttributeName] = font

    configNames = Hash.new
    @heights = Hash.new

    @buildSettings.keys.sort.each do |productName|
      list = @buildSettings[productName]
      list.keys.sort.each do |targetName|
        setting = list[targetName]
        setting["!NAME"] = targetName
        width = calcWidth(0, productName)
        width = calcWidth(width, targetName)
        column = NSTableColumn.new.initWithIdentifier(
          {:productName => productName, :targetName => targetName})
        column.headerCell.setStringValue(productName)
        @tableView.addTableColumn(column)
        setting.keys.each do |key|
          cell = setting[key]
          if cell.class == NSMutableArray
            height = cell.size + 2
            cell.each do |line|
              width = calcWidth(width, line + "    \"\",")
            end
          else
            height = 1
            width = calcWidth(width, cell)
          end
          configNames[key] = true
          @heights[key] = height if @heights[key].nil? || height > @heights[key]
        end
        column.width = width
      end
    end
    @configNames = configNames.keys.sort

    width = 0
    @configNames.each do |name|
      width = calcWidth(width, name)
    end
    index_column.width = width

    @tableView.dataSource = self
    @tableView.delegate = self
  end

  def numberOfRowsInTableView(view)
    @configNames.size
  end

  def tableView(view, objectValueForTableColumn:column, row:index) 
    i = column.identifier
    if i.nil?
      @configNames[index]
    else
      @buildSettings[i[:productName]][i[:targetName]][@configNames[index]]
    end
  end

#  def tableView(view, setObjectValue:object, forTableColumn:column, row:index)
#    i = column.identifier
#    return if @configNames[index] == "!NAME" or i.nil?
#    cell = @buildSettings[i[:productName]][i[:targetName]][@configNames[index]]
#    if cell.to_s != object
#      @buildSettings[
#        i[:productName]][i[:targetName]][@configNames[index]] = object
#    end
#  end

  def tableView(view, heightOfRow:row)
    @heights[@configNames[row]] * view.rowHeight
  end
end

class MyDocument < NSDocument
  attr_reader :fileWrapper
  attr_accessor :controller
	def windowNibName
		'MyDocument'
	end

  def readFromFileWrapper(fileWrapper, ofType:typeName, error:outError)
    @fileWrapper = fileWrapper.fileWrappers["project.pbxproj"]
    true
  end

  def writeToURL(url, ofType:typeName, error:outError)
    @controller.save(url)
  end

	def displayName
		fileURL ? super : super.sub(/^[[:upper:]]/) {|s| s.downcase}
	end
end
