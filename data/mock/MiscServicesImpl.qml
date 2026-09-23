/*
** Copyright (C) 2025 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

Item {
	id: root

	// Animate gps values.
	Instantiator {
		model: FilteredServiceModel { serviceTypes: ["gps"] }
		delegate: Item {
			id: gps

			required property string uid

			MockDataRangeAnimator {
				active: Global.mainView && Global.mainView.mainViewVisible
				stepSize: 8
				maximumValue: MockManager.value(Global.systemSettings.serviceUid + "/Settings/Gui/Gauges/Speed/Max") || 0
				VeQuickItem { uid: gps.uid + "/Speed" }
			}
		}
	}

	// Animate meteo values.
	Instantiator {
		model: FilteredServiceModel { serviceTypes: ["meteo"] }
		delegate: Item {
			id: meteo

			required property string uid

			MockDataRandomizer {
				active: Global.mainView && Global.mainView.mainViewVisible
				VeQuickItem { uid: meteo.uid + "/Irradiance" }
				VeQuickItem { uid: meteo.uid + "/WindSpeed" }
				VeQuickItem { uid: meteo.uid + "/InstallationPower" }
			}
			MockDataRangeAnimator {
				active: Global.mainView && Global.mainView.mainViewVisible
				stepSize: 45
				maximumValue: 360
				VeQuickItem { uid: meteo.uid + "/WindDirection" }
			}
		}
	}

	// Simulate the OutEquip AC driver's on-demand BLE connection: a nonzero
	// /Ac/ConnectRequest connects after a short delay and holds a 60s lease
	// that each refresh renews; 0 disconnects immediately.
	Instantiator {
		model: FilteredServiceModel { serviceTypes: ["switch"] }
		delegate: Item {
			id: acSwitch

			required property string uid

			VeQuickItem {
				id: connectionState
				uid: acSwitch.uid + "/Ac/ConnectionState"
			}

			VeQuickItem {
				uid: acSwitch.uid + "/Ac/ConnectRequest"
				onValueChanged: {
					if (!connectionState.valid) {
						return
					}
					if (value) {
						leaseTimer.restart()
						if (connectionState.value !== 2) {
							connectionState.setValue(1)
							connectTimer.restart()
						}
					} else {
						connectTimer.stop()
						leaseTimer.stop()
						connectionState.setValue(0)
					}
				}
			}

			Timer {
				id: connectTimer
				interval: 1500
				onTriggered: connectionState.setValue(2)
			}

			Timer {
				id: leaseTimer
				interval: 60000
				onTriggered: {
					connectTimer.stop()
					connectionState.setValue(0)
				}
			}
		}
	}
}
