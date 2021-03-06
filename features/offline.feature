Feature: offline cpu

  cpu0 is not hot pluggable in some of our environments, so certain tests are
  marked with the RequireHotplugCpu0 tag.

  Background: Enable cpus before each test in this file
    Given I enable cpu 0
    And I enable cpu 1

  Scenario: Packets sent on cpu0 are counted as such when cpu1 is offline
    Given I wait 0.2 seconds for a command to start up
    And I disable cpu 1
    When I run `sudo timeout -s INT 2 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c3 localhost` on cpu 0
    Then the stdout from "sudo timeout -s INT 2 ../../rxtxcpu lo" should contain exactly:
    """
    12 packets captured on cpu0.
    12 packets captured total.
    """

  @RequireHotplugCpu0
  Scenario: Packets sent on cpu1 are counted as such when cpu0 is offline
    Given I wait 0.2 seconds for a command to start up
    And I disable cpu 0
    When I run `sudo timeout -s INT 2 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c3 localhost` on cpu 1
    Then the stdout from "sudo timeout -s INT 2 ../../rxtxcpu lo" should contain exactly:
    """
    12 packets captured on cpu1.
    12 packets captured total.
    """

  Scenario: Packets sent on cpu0 are counted as such when cpu1 is offline and flipped online
    Given I wait 0.2 seconds for a command to start up
    And I disable cpu 1
    When I run `sudo timeout -s INT 3 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c3 localhost` on cpu 0 in background
    And I enable cpu 1
    And I run `ping -i0.2 -c1 localhost` on cpu 1
    Then the stdout from "sudo timeout -s INT 3 ../../rxtxcpu lo" should contain exactly:
    """
    12 packets captured on cpu0.
    12 packets captured total.
    """

  @RequireHotplugCpu0
  Scenario: Packets sent on cpu1 are counted as such when cpu0 is offline and flipped online
    Given I wait 0.2 seconds for a command to start up
    And I disable cpu 0
    When I run `sudo timeout -s INT 3 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c3 localhost` on cpu 1 in background
    And I enable cpu 0
    And I run `ping -i0.2 -c1 localhost` on cpu 0
    Then the stdout from "sudo timeout -s INT 3 ../../rxtxcpu lo" should contain exactly:
    """
    12 packets captured on cpu1.
    12 packets captured total.
    """

  @RequireHotplugCpu0
  Scenario: Packets sent on cpu0 are counted as such when processed before cpu0 is flipped offline
    Given I wait 0.2 seconds for a command to start up
    When I run `sudo timeout -s INT 3 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c1 localhost` on cpu 1 in background
    And I run `ping -i0.2 -c3 localhost` on cpu 0
    And I disable cpu 0
    And I run `ping -i0.2 -c1 localhost` on cpu 1
    Then the stdout from "sudo timeout -s INT 3 ../../rxtxcpu lo" should contain exactly:
    """
    12 packets captured on cpu0.
    8 packets captured on cpu1.
    20 packets captured total.
    """

  Scenario: Packets sent on cpu1 are counted as such when processed before cpu1 is flipped offline
    Given I wait 0.2 seconds for a command to start up
    When I run `sudo timeout -s INT 3 ../../rxtxcpu lo` in background
    And I run `ping -i0.2 -c1 localhost` on cpu 0 in background
    And I run `ping -i0.2 -c3 localhost` on cpu 1
    And I disable cpu 1
    And I run `ping -i0.2 -c1 localhost` on cpu 0
    Then the stdout from "sudo timeout -s INT 3 ../../rxtxcpu lo" should contain exactly:
    """
    8 packets captured on cpu0.
    12 packets captured on cpu1.
    20 packets captured total.
    """

  Scenario: Enable cpus after all tests in this file
    Given I enable cpu 0
    And I enable cpu 1
