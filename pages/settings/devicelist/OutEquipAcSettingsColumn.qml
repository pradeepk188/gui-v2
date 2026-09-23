/*
** Copyright (C) 2026 Victron Energy B.V.
** See LICENSE.txt for license information.
*/

import QtQuick
import Victron.VenusOS

/*
	Extra controls for an OutEquipPro rooftop AC bridged onto a
	com.victronenergy.switch service by the VeOutEquipAC driver.

	Power on/off is the device's regular SwitchableOutput, shown here as a
	direct toggle rather than the generic single-output sub-page PageSwitch.qml
	would otherwise     link to (unnecessary ceremony for a plain on/off relay --
	see the toggle below). The driver additionally publishes mode/fan speed/
	setpoint/swing/temperature/voltage under a non-standard /Ac/* namespace,
	which the stock switch page has no concept of -- this column adds native
	controls for those paths too.

	The AC's BLE module only accepts one connection at a time, so the driver
	does not hold it permanently (that would lock out the phone app). It only
	connects after the user presses Connect here, and only for as long as
	this page stays open: while a connection is wanted, a timer keeps
	refreshing /Ac/ConnectRequest with a new nonzero value (the driver treats
	it as a lease that expires ~60s after the last refresh). Pressing
	Disconnect, or leaving the page, writes 0 to release it immediately.

	Only renders when the device publishes /Ac/ConnectionState (or /Ac/Mode,
	for older driver versions), so it has no effect on any other switch/relay
	device.
*/
SettingsColumn {
	id: root

	required property string serviceUid
	// True while the page hosting this column is the current page. Leaving
	// the page (going back, or opening another page) drops the connection.
	property bool pageActive

	readonly property string _acPrefix: root.serviceUid + "/Ac/"

	// Older drivers without on-demand connection have no ConnectionState and
	// are always connected, so their controls stay enabled.
	readonly property bool _onDemand: connectionStateItem.valid
	readonly property bool _connected: !_onDemand
			|| connectionStateItem.value === root._stateConnected
	property bool _connectWanted

	// /Ac/ConnectionState values published by the driver
	readonly property int _stateConnecting: 1
	readonly property int _stateConnected: 2
	readonly property int _stateFailed: 3

	function _releaseConnection() {
		root._connectWanted = false
		if (connectRequestItem.valid && connectRequestItem.value !== 0) {
			connectRequestItem.setValue(0)
		}
	}

	visible: connectionStateItem.valid || modeItem.valid
	preferredVisible: visible
	width: parent?.width ?? 0

	onPageActiveChanged: {
		if (!pageActive) {
			_releaseConnection()
		}
	}
	Component.onDestruction: _releaseConnection()

	VeQuickItem {
		id: modeItem
		uid: root._acPrefix + "Mode"
	}

	VeQuickItem {
		id: connectionStateItem
		uid: root._acPrefix + "ConnectionState"
	}

	VeQuickItem {
		id: connectRequestItem
		uid: root._acPrefix + "ConnectRequest"
	}

	// Refreshes the driver's connect lease while a connection is wanted. The
	// value must differ on every write (vedbus ignores same-value writes), so
	// the current time in seconds is used.
	Timer {
		interval: 20000
		repeat: true
		triggeredOnStart: true
		running: root._onDemand && root._connectWanted && root.pageActive
		onTriggered: connectRequestItem.setValue(Math.floor(Date.now() / 1000))
	}

	SectionHeader {
		text: "Air conditioner"
	}

	ListText {
		text: "Connection"
		preferredVisible: root._onDemand
		secondaryText: {
			switch (connectionStateItem.value) {
			case root._stateConnecting:
				return "Connecting…"
			case root._stateConnected:
				return "Connected"
			case root._stateFailed:
				return "Connection failed, retrying…"
			default:
				return "Disconnected"
			}
		}
	}

	ListButton {
		text: root._connectWanted
			  ? "Release the AC for the phone app"
			  : "Connect to read and control the AC"
		secondaryText: root._connectWanted ? "Disconnect" : "Connect"
		preferredVisible: root._onDemand
		writeAccessLevel: VenusOS.User_AccessType_User
		onClicked: {
			if (root._connectWanted) {
				root._releaseConnection()
			} else {
				root._connectWanted = true
			}
		}
	}

	// The device's SwitchableOutput already provides this control, but the
	// generic single-output delegate on this page (see PageSwitch.qml)
	// always links to a sub-page -- appropriate for output types that
	// genuinely need one (color wheels, sliders, dropdowns, etc.), but
	// unnecessary ceremony for this AC's plain on/off toggle. PageSwitch.qml
	// suppresses that generic sub-page entry for this device in favour of
	// this direct toggle.
	ListSwitch {
		text: "Power"
		enabled: root._connected
		dataItem.uid: root.serviceUid + "/SwitchableOutput/output_1/State"
	}

	ListRadioButtonGroup {
		text: "Mode"
		enabled: root._connected
		dataItem.uid: root._acPrefix + "Mode"
		optionModel: [
			{ display: "Cool", value: 1 },
			{ display: "Heat", value: 2 },
			{ display: "Fan", value: 3 },
			{ display: "Eco Cool", value: 4 },
			{ display: "Sleep Cool", value: 5 },
			{ display: "Turbo Cool", value: 6 },
			{ display: "Wet/Dehumidify", value: 7 },
		]
	}

	ListSlider {
		text: "Fan speed"
		enabled: root._connected
		dataItem.uid: root._acPrefix + "FanSpeed"
		from: 1
		to: 5
		stepSize: 1
	}

	ListSpinBox {
		// The setpoint register carries a plain integer in whole Fahrenheit
		// degrees, so the 63-86 range below is in °F (~17-30 °C).
		text: "Setpoint"
		enabled: root._connected
		dataItem.uid: root._acPrefix + "SetpointTemperature"
		from: 63
		to: 86
		stepSize: 1
		decimals: 0
		suffix: Units.defaultUnitString(VenusOS.Units_Temperature_Fahrenheit)
	}

	ListSwitch {
		text: "Swing"
		enabled: root._connected
		dataItem.uid: root._acPrefix + "Swing"
	}

	ListTemperature {
		text: "Intake temperature"
		dataItem.uid: root._acPrefix + "IntakeTemperature"
		dataItem.sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Fahrenheit)
		preferredVisible: dataItem.valid
		decimals: 0
	}

	ListTemperature {
		text: "Outlet temperature"
		dataItem.uid: root._acPrefix + "OutletTemperature"
		dataItem.sourceUnit: Units.unitToVeUnit(VenusOS.Units_Temperature_Fahrenheit)
		preferredVisible: dataItem.valid
		decimals: 0
	}

	ListQuantity {
		text: "Supply voltage"
		dataItem.uid: root._acPrefix + "SupplyVoltage"
		preferredVisible: dataItem.valid
		unit: VenusOS.Units_Volt_DC
		decimals: 1
	}
}
