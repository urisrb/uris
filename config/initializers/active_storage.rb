%i[active_storage_blob active_storage_attachment active_storage_variant_record].each do |model|
  ActiveSupport.on_load(model) { include TenantScoped }
end
