require 'manageiq/network_discovery/port_scanner'

module ManageIQ
  module NetworkDiscovery
    class VMwareEsxVcProbe
      ESX_PORTS = [902, 903]
      VC_PORTS = [
        [
          135, # VC < 5.1 or
          7444  # VC >= 5.1
        ], # and
        [
          139,  # VC < 5.1 or
          2012, # VC >= 5.1
          2013,
          2014
        ]
      ]

      def self.probe(ost)
        # First check if we can access the VMware webservice before even trying the port scans.
        begin
          require 'VMwareWebService/MiqVimClientBase'
          MiqVimClientBase.new(ost.ipaddr, "test", "test")
        rescue => err
          $log.debug "VMwareEsxVcProbe: Failed to connect to VMware webservice: #{err}. ip = #{ost.ipaddr}" if $log
          return
        end

        $log.debug "VMwareEsxVcProbe: ip = #{ost.ipaddr}, Connected to VMware webservice. Machine is either ESX or VirtualCenter." if $log

        # Next check for ESX or VC. Since VC shares some port numbers with ESX, we check VC before ESX

        # TODO: See if there is a way we can check ESX first, and without having to
        #   also check VC, since it is more likely there will be more ESX servers on
        #   a network than VC servers.

        checked_vc = false
        found_vc = false

        # Check if we have VC ports
        if ost.discover_types.include?(:virtualcenter)
          checked_vc = true

          if PortScanner.portAndOrScan?(ost, VC_PORTS)
            ost.os << :mswin
            ost.hypervisor << :virtualcenter
            found_vc = true
            $log.debug "VMwareEsxVcProbe: ip = #{ost.ipaddr}, Machine is VirtualCenter." if $log
          end
        end

        # Check if we have ESX ports open
        if !found_vc && ost.discover_types.include?(:esx) && PortScanner.portOrScan?(ost, ESX_PORTS)

          # Since VC may share ports with ESX, but it may have not already been
          # checked due to filtering, check that this is not a VC server
          if checked_vc || !PortScanner.portAndOrScan?(ost, VC_PORTS)
            ost.os << :linux
            ost.hypervisor << :esx
            $log.debug "VMwareEsxVcProbe: ip = #{ost.ipaddr}, Machine is an ESX server." if $log
          end
        end
      end
    end # class VMwareEsxVcProbe
  end
end
