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
}
