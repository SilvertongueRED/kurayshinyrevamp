# TEMP DIAGNOSTIC — party menu builder tracer. Safe to delete.
begin
  loc = PokemonPartyScreen.instance_method(:pbPokemonScreen).source_location rescue "n/a"
  File.open("party_menu_diag.log", "a") { |f| f.puts "[#{Time.now rescue '?'}] LOADED diag. active pbPokemonScreen = #{loc.inspect}" }
rescue => e
  (File.open("party_menu_diag.log","a"){|f| f.puts "DIAG load err #{e.class}: #{e.message}"}) rescue nil
end

class PokemonParty_Scene
  unless method_defined?(:_diag_party_show)
    alias _diag_party_show pbShowCommands
    def pbShowCommands(*args)
      begin
        msg = args[0]; cmds = args[1]
        if msg.is_a?(String) && msg.include?("Do what with")
          File.open("party_menu_diag.log", "a") do |f|
            f.puts "[#{Time.now}] SHOWCMDS msg=#{msg.inspect}"
            f.puts "  commands=#{cmds.inspect}"
            (caller(0)[1,12] || []).each { |c| f.puts "  <- #{c}" }
          end
        end
      rescue => e
        (File.open("party_menu_diag.log","a"){|f| f.puts "DIAGERR #{e.class}: #{e.message}"}) rescue nil
      end
      return _diag_party_show(*args)
    end
  end
end
