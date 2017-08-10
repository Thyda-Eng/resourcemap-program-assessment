module Collection::CsvConcern
  extend ActiveSupport::Concern

  def csv_template
    CSV.generate do |csv|
      csv << csv_header
      csv << [1, "Site 1", 1.234, 5.678]
      csv << [2, "Site 2", 3.456, 4.567]
    end
  end

  def to_csv(elastic_search_api_results = new_search.unlimited.api_results, current_user)
    layers = self.layers.all
    fields = []
    layers.each do |layer|
      allFields = layer.fields
      allFields.each do |field|
        fields.push(field)
      end
    end
    hierarchy_fields = {}
    CSV.generate do |csv|
      header = ['resmap-id', 'name', 'lat', 'long']
      fields.each do |field|
        field_header = field.csv_header
        if field_header.kind_of?(Array)
          header = header + field_header
        else
          header << field.csv_header
        end
      end
      header << 'start entry date'
      header << 'end entry date'
      header << 'last updated'
      csv << header

      elastic_search_api_results.each do |result|
        source = result['_source']

        row = [source['id'], source['name'], source['location'].try(:[], 'lat'), source['location'].try(:[], 'lon')]
        fields.each do |field|
          if field.kind == 'yes_no'
            row << (Field.yes?(source['properties'][field.code]) ? 'yes' : 'no')
          elsif field.kind == 'photo'
            if source['properties'][field.code].present?
              row << "http://#{Settings.host}/view_photo?uuid=#{source['uuid']}&file_name=#{source['properties'][field.code]}"
            else
              row << ""
            end
          elsif field.kind == "select_one" || field.kind == "select_many"
            row << field.value_for_csv(source['properties'][field.code])
          elsif field.kind == "hierarchy"
            hierarchy_fields[field.id.to_s] = field.transform()
            hierarchy_fields[field.id.to_s]["depth"] = field.get_longest_depth()
            field.config["hierarchy"] = hierarchy_fields[field.id.to_s]["hierarchy"]
            level = 0
            arr_level = []
            if source['properties'][field.code]
               item = field.find_hierarchy_by_id source['properties'][field.code]
              while item
                arr_level.insert(0, item[:name])
                item = field.find_hierarchy_by_id item[:parent_id]
              end
            end

            if hierarchy_fields[field.id.to_s]["depth"] == 0
              row << arr_level[level] || ""
            end

            while level < hierarchy_fields[field.id.to_s]["depth"]
              row << arr_level[level] || ""
              level = level + 1
            end
          else
            row << Array(source['properties'][field.code]).join(", ")
          end
        end

        updated_at = Site.parse_time(source['updated_at']).strftime("%d/%m/%Y %H:%M:%S")
        start_entry_date = Site.parse_time(source['start_entry_date']).strftime("%d/%m/%Y %H:%M:%S")
        end_entry_date = Site.parse_time(source['end_entry_date']).strftime("%d/%m/%Y %H:%M:%S")

        row << start_entry_date
        row << end_entry_date
        row << updated_at
        csv << row
      end
    end
  end

  def location_csv(locations)
    CSV.generate do |csv|
      locations.each do |location|
        csv << [location["code"], location["name"], location["latitude"], location["longitude"]]
      end
    end
  end

  def sample_csv(user = nil)
    fields = self.fields.all

    CSV.generate do |csv|
      header = ['name', 'lat', 'long']
      writable_fields = writable_fields_for(user)
      writable_fields.each { |field|
        field_header = field.csv_header
        if field_header.kind_of?(Array)
          header = header + field_header
        else
          header << field.csv_header
        end
      }
      csv << header
      row = ['Paris', 48.86, 2.35]
      writable_fields.each do |field|
        if field.csv_header.kind_of?(Array)
          field.csv_header.each do |header|
            row << Array(field.sample_value user).join(", ")
          end
        else
          row << Array(field.sample_value user).join(", ")
        end
      end
      csv << row
    end
  end

  def sample_members_csv(user = nil)
    fields = self.fields.all

    CSV.generate do |csv|
      header = ['email','None','Read','Update','Admin','View data submitted by other user','Edit data submitted by other user']
      csv << header
      row = ['sample_user@email.com',0,0,0,1,1,1]
      csv << row
    end
  end

  def import_csv(user, string_or_io)
    Collection.transaction do
      csv = CSV.new string_or_io, return_headers: false

      new_sites = []
      csv.each do |row|
        next unless row[0].present? && row[0] != 'resmap-id'

        site = sites.new name: row[1].strip
        site.mute_activities = true
        site.lat = row[2].strip if row[2].present?
        site.lng = row[3].strip if row[3].present?
        new_sites << site
      end

      new_sites.each &:save!

      Activity.create! item_type: 'collection', action: 'csv_imported', collection_id: id, user_id: user.id, 'data' => {'sites' => new_sites.length}
    end
  end

  def decode_hierarchy_csv(string)

    csv = CSV.parse(string)

    # First read all items into a hash
    # And validate it's content
    items = validate_format(csv)


    # Add to parents
    items.each do |order, item|
      if item[:parent].present? && !item[:error].present?
        parent_candidates = items.select{|key, hash| hash[:id] == item[:parent]}

        if parent_candidates.any?
          parent = parent_candidates.first[1]
        end

        if parent
          parent[:sub] ||= []
          parent[:sub] << item
        end
      end
    end


    # Remove those that have parents, and at the same time delete their parent key
    items = items.reject do |order, item|
      if item[:parent] && !item[:error].present?
        item.delete :parent
        true
      else
        false
      end
    end


    items.values

    rescue Exception => ex
      return [{error: ex.message}]

  end

  def decode_location_csv(string)
    csv = CSV.parse(string)

    items = validate_format_location(csv)

    locations = []
    items.each do |item|
      locations.push item[1]
    end

    locations

    rescue Exception => ex
      return [{error: ex.message}]
  end

  def validate_format_location(csv)
    i = 0
    items = {}
    csv.each do |row|
      item = {}
      if row[0] == 'Code'
        next
      else
        i = i+1
        item[:order] = i

        if row.length != 4
          item[:error] = "Wrong format."
          item[:error_description] = "Invalid column number"
        else

          #Check unique name
          name = row[1].strip

          #Check unique id
          code = row[0].strip
          if items.any?{|item| item.second[:code] == code}
            item[:error] = "Invalid code."
            item[:error_description] = "location code should be unique"
            error = true
          end

          if !error
            item[:code] = code
            item[:name] = name
            item[:latitude] = row[2].strip
            item[:longitude] = row[3].strip
          end
        end

        items[item[:order]] = item
      end
    end
    items
  end

  def validate_format(csv)
    i = 0
    items = {}
    csv.each do |row|
      item = {}
      if row[0] == 'ID'
        next
      else
        i = i+1
        item[:order] = i

        if row.length != 3
          item[:error] = "Wrong format."
          item[:error_description] = "Invalid column number"
        else

          #Check unique name
          name = row[2].strip

          #Check unique id
          id = row[0].strip
          if items.any?{|item| item.second[:id] == id}
            item[:error] = "Invalid id."
            item[:error_description] = "Hierarchy id should be unique"
            error = true
          end

          #Check parent id exists
          parent_id = row[1]
          if(parent_id.present? && !csv.any?{|csv_row| csv_row[0].strip == parent_id.strip})
            item[:error] = "Invalid parent value."
            item[:error_description] = "ParentID should match one of the Hierarchy ids"
            error = true
          end

          if !error
            item[:id] = id
            item[:parent] = row[1].strip if row[1].present?
            item[:name] = name
          end
        end

        items[item[:order]] = item
      end
    end
    items
  end

  private

  def csv_header
    ["Site ID", "Name", "Lat", "Lng"]
  end


end
