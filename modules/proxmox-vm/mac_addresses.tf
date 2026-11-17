resource "random_id" "mac_address_1" {
  byte_length = 1
}
resource "random_id" "mac_address_2" {
  byte_length = 1
}
resource "random_id" "mac_address_3" {
  byte_length = 1
}

resource "random_id" "mac_address_1_ceph" {
  byte_length = 1
}
resource "random_id" "mac_address_2_ceph" {
  byte_length = 1
}
resource "random_id" "mac_address_3_ceph" {
  byte_length = 1
}

locals {
  # Convert the random bytes to a MAC address format
  mac_address = upper(format("BC:24:11:%02x:%02x:%02x",
    random_id.mac_address_1.dec,
    random_id.mac_address_2.dec,
    random_id.mac_address_3.dec
  ))
  mac_address_ceph = upper(format("BC:24:11:%02x:%02x:%02x",
    random_id.mac_address_1_ceph.dec,
    random_id.mac_address_2_ceph.dec,
    random_id.mac_address_3_ceph.dec
  ))

  # EUI-64 interface id of net0 (BC:24:11:xx:yy:zz -> be24:11ff:fexx:yyzz) and
  # the SLAAC address the guest derives from it inside the IPv6 prefix.
  # ponytail: assumes network_prefix6 is a /64 written as "....::/64".
  eui64_iid = format("be24:11ff:fe%02x:%02x%02x",
    random_id.mac_address_1.dec,
    random_id.mac_address_2.dec,
    random_id.mac_address_3.dec
  )
  slaac_address6 = "${trimsuffix(split("/", var.network_prefix6)[0], "::")}:${local.eui64_iid}"
}
