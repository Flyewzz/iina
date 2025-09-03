//
//  QuickSettingViewController.swift
//  iina
//
//  Created by lhc on 12/8/16.
//  Copyright © 2016 lhc. All rights reserved.
//

import Cocoa

fileprivate let eqUserDefinedProfileMenuItemTag = 0
fileprivate let eqPresetProfileMenuItemTag = 1
fileprivate let eqDeleteMenuItemTag = -1
fileprivate let eqRenameMenuItemTag = -2
fileprivate let eqSaveMenuItemTag = -3
fileprivate let eqCustomMenuItemTag = 1000

/// Formatter for `customSpeedTextField`.
///
/// Configure the number formatter in code instead of the XIB so it is easier to follow.
fileprivate let speedFormatter: NumberFormatter = {
  let fmt = NumberFormatter()
  fmt.numberStyle = .decimal
  fmt.usesGroupingSeparator = true
  fmt.maximumSignificantDigits = 25  // just make very big
  fmt.minimumFractionDigits = 0
  fmt.maximumFractionDigits = 6  // matches mpv behavior
  fmt.usesSignificantDigits = false
  fmt.roundingMode = .halfDown   // matches mpv behavior
  fmt.minimum = NSNumber(floatLiteral: AppData.mpvMinPlaybackSpeed)
  return fmt
}()

struct SubtitleBlock {
  let index: Int
  let timestamp: String
  let text: String
}

extension TimeInterval {
    func formattedTime() -> String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

class QuickSettingViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, SidebarViewController {
  override var nibName: NSNib.Name {
    return NSNib.Name("QuickSettingViewController")
  }

  let sliderSteps = 24.0

  enum TabViewType: Equatable {
    case video
    case audio
    case sub

    init(buttonTag: Int) {
      self = [.video, .audio, .sub][at: buttonTag] ?? .video
    }

    init?(name: String) {
      switch name {
      case "video":
        self = .video
      case "audio":
        self = .audio
      case "sub":
        self = .sub
      default:
        self = .video
      }
    }

    var buttonTag: Int {
      switch self {
      case .video: return 0
      case .audio: return 1
      case .sub: return 2
      default: return 0
      }
    }

    var name: String {
      switch self {
      case .video: return "video"
      case .audio: return "audio"
      case .sub: return "sub"
      }
    }
  }

  /**
   Similar to the one in `PlaylistViewController`.
   Since IBOutlet is `nil` when the view is not loaded at first time,
   use this variable to cache which tab it need to switch to when the
   view is ready. The value will be handled after loaded.
   */
  private var pendingSwitchRequest: TabViewType?

  weak var player: PlayerCore!

  weak var mainWindow: MainWindowController! {
    didSet {
      self.player = mainWindow.player
    }
  }

  var currentTab: TabViewType = .video

  var observers: [NSObjectProtocol] = []

  @IBOutlet weak var videoTabScrollView: NSScrollView!
  @IBOutlet weak var videoTabContentViewWidthConstraint: NSLayoutConstraint!

  @IBOutlet weak var videoTabBtn: NSButton!
  @IBOutlet weak var audioTabBtn: NSButton!
  @IBOutlet weak var subTabBtn: NSButton!
  @IBOutlet weak var tabView: NSTabView!

  @IBOutlet weak var buttonTopConstraint: NSLayoutConstraint!

  @IBOutlet weak var videoTableView: NSTableView!
  @IBOutlet weak var audioTableView: NSTableView!
  @IBOutlet weak var subTableView: NSTableView!
  @IBOutlet weak var secSubTableView: NSTableView!
  
  @IBOutlet weak var languageDropdown: NSComboBox!
  @IBOutlet weak var languageLabel: NSTextField!
  @IBOutlet weak var languageDropdown2: NSComboBox!
  @IBOutlet weak var languageLabel2: NSTextField!

  @IBOutlet weak var rotateSegment: NSSegmentedControl!

  @IBOutlet weak var aspectSegment: NSSegmentedControl!
  @IBOutlet weak var customAspectTextField: NSTextField!

  @IBOutlet weak var cropSegment: NSSegmentedControl!

  @IBOutlet weak var speedSlider: NSSlider!
  @IBOutlet weak var speedSliderIndicator: NSTextField!
  @IBOutlet weak var speedSliderConstraint: NSLayoutConstraint!
  @IBOutlet weak var speedSliderContainerView: NSView!

  @IBOutlet weak var speedSlider0_25xLabel: NSTextField!
  @IBOutlet weak var speedSlider1xLabel: NSTextField!
  @IBOutlet weak var speedSlider4xLabel: NSTextField!
  @IBOutlet weak var speedSlider16xLabel: NSTextField!
  @IBOutlet var speedSlider1xLabelCenterXConstraint: NSLayoutConstraint!
  @IBOutlet var speedSlider4xLabelCenterXConstraint: NSLayoutConstraint!
  @IBOutlet var speedSlider1xLabelPrevLabelConstraint: NSLayoutConstraint!
  @IBOutlet var speedSlider4xLabelPrevLabelConstraint: NSLayoutConstraint!
  @IBOutlet var speedSlider16xLabelPrevLabelConstraint: NSLayoutConstraint!

  @IBOutlet weak var customSpeedTextField: NSTextField!
  @IBOutlet weak var speedResetBtn: NSButton!
  @IBOutlet weak var switchHorizontalLine: NSBox!
  @IBOutlet weak var switchHorizontalLine2: NSBox!
  @IBOutlet weak var hardwareDecodingSwitch: NSSwitch!
  @IBOutlet weak var deinterlaceSwitch: NSSwitch!
  @IBOutlet weak var hdrSwitch: NSSwitch!
  @IBOutlet weak var hardwareDecodingLabel: NSTextField!
  @IBOutlet weak var deinterlaceLabel: NSTextField!
  @IBOutlet weak var hdrLabel: NSTextField!

  @IBOutlet weak var brightnessSlider: NSSlider!
  @IBOutlet weak var contrastSlider: NSSlider!
  @IBOutlet weak var saturationSlider: NSSlider!
  @IBOutlet weak var gammaSlider: NSSlider!
  @IBOutlet weak var hueSlider: NSSlider!

  @IBOutlet weak var audioDelaySlider: NSSlider!
  @IBOutlet weak var audioDelaySliderIndicator: NSTextField!
  @IBOutlet weak var audioDelaySliderConstraint: NSLayoutConstraint!
  @IBOutlet weak var customAudioDelayTextField: NSTextField!

  @IBOutlet weak var hideSwitch: NSSwitch!
  @IBOutlet weak var secHideSwitch: NSSwitch!
  @IBOutlet weak var subLoadSegmentedControl: NSSegmentedControl!
  @IBOutlet weak var subDelaySlider: NSSlider!
  @IBOutlet weak var subDelaySliderIndicator: NSTextField!
  @IBOutlet weak var subDelaySliderConstraint: NSLayoutConstraint!
  @IBOutlet weak var customSubDelayTextField: NSTextField!
  @IBOutlet weak var subSegmentedControl: NSSegmentedControl!

  @IBOutlet weak var eqPopUpButton: NSPopUpButton!
  @IBOutlet weak var audioEqSlider1: NSSlider!
  @IBOutlet weak var audioEqSlider2: NSSlider!
  @IBOutlet weak var audioEqSlider3: NSSlider!
  @IBOutlet weak var audioEqSlider4: NSSlider!
  @IBOutlet weak var audioEqSlider5: NSSlider!
  @IBOutlet weak var audioEqSlider6: NSSlider!
  @IBOutlet weak var audioEqSlider7: NSSlider!
  @IBOutlet weak var audioEqSlider8: NSSlider!
  @IBOutlet weak var audioEqSlider9: NSSlider!
  @IBOutlet weak var audioEqSlider10: NSSlider!

  @IBOutlet weak var subScaleSlider: NSSlider!
  @IBOutlet weak var subScaleResetBtn: NSButton!
  @IBOutlet weak var subPosSlider: NSSlider!

  @IBOutlet weak var subTextColorWell: NSColorWell!
  @IBOutlet weak var subTextSizePopUp: NSPopUpButton!
  @IBOutlet weak var subTextBorderColorWell: NSColorWell!
  @IBOutlet weak var subTextBorderWidthPopUp: NSPopUpButton!
  @IBOutlet weak var subTextBgColorWell: NSColorWell!
  @IBOutlet weak var subTextFontBtn: NSButton!

  private lazy var eqSliders: [NSSlider] = [audioEqSlider1, audioEqSlider2, audioEqSlider3, audioEqSlider4, audioEqSlider5,
                                            audioEqSlider6, audioEqSlider7, audioEqSlider8, audioEqSlider9, audioEqSlider10]

  private var lastUsedProfileName: String = ""
  private var inputString: String = ""
  
  // Dictionary of language names and their 2-letter codes
  let languages: [String: String] = [
      "Arabic": "ar",
      "Azerbaijani": "az",
      "Catalan": "ca",
      "Chinese": "zh",
      "Czech": "cs",
      "Danish": "da",
      "Dutch": "nl",
      "English": "en",
      "Esperanto": "eo",
      "Finnish": "fi",
      "French": "fr",
      "German": "de",
      "Greek": "el",
      "Hebrew": "he",
      "Hindi": "hi",
      "Hungarian": "hu",
      "Indonesian": "id",
      "Irish": "ga",
      "Italian": "it",
      "Japanese": "ja",
      "Korean": "ko",
      "Persian": "fa",
      "Polish": "pl",
      "Portuguese": "pt",
      "Russian": "ru",
      "Slovak": "sk",
      "Spanish": "es",
      "Swedish": "sv",
      "Turkish": "tr",
      "Ukrainian": "uk",
  ]
  
  // selected languages (English, Russian, Polish, etc.)
  var selectedLanguage: (String, String) = ("Polish", "pl")
  var selectedLanguage2: (String, String) = ("Russian", "ru") // Второй язык может быть пустым
  

  var downShift: CGFloat = 0 {
    didSet {
      buttonTopConstraint.constant = downShift
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    withAllTableViews { (view, _) in
      view.delegate = self
      view.dataSource = self
      view.superview?.superview?.layer?.cornerRadius = 4
    }

    // colors
    withAllTableViews { tableView, _ in tableView.backgroundColor = NSColor(named: .sidebarTableBackground)! }

    if pendingSwitchRequest == nil {
      updateTabActiveStatus()
    } else {
      switchToTab(pendingSwitchRequest!)
      pendingSwitchRequest = nil
    }

    speedResetBtn.toolTip = NSLocalizedString("quicksetting.reset_speed", comment: "Reset speed to 1x")

    subLoadSegmentedControl.image(forSegment: 1)?.isTemplate = true
    switchHorizontalLine.wantsLayer = true
    switchHorizontalLine.layer?.opacity = 0.5
    switchHorizontalLine2.wantsLayer = true
    switchHorizontalLine2.layer?.opacity = 0.5

    // Localize decimal format of numbers
    speedSlider0_25xLabel.stringValue = "\(0.25.string)x"
    // Unclear if these need to be localized. Better to be safe?
    speedSlider1xLabel.stringValue = "\(1.string)x"
    speedSlider4xLabel.stringValue = "\(4.string)x"
    speedSlider16xLabel.stringValue = "\(16.string)x"

    customSpeedTextField.formatter = speedFormatter

    if let data = UserDefaults.standard.data(forKey: Preference.Key.userEQPresets.rawValue),
       let dict = try? JSONDecoder().decode(Dictionary<String, EQProfile>.self, from: data) {
      userEQs = dict
    }

    eqPopUpButton.menu!.delegate = self
    presetEQs.forEach { preset in
      eqPopUpButton.menu?.addItem(withTitle: preset.name, tag: eqPresetProfileMenuItemTag, obj: preset.localizationKey)
    }
    eqPopUpButton.selectItem(withTag: eqCustomMenuItemTag)
    lastUsedProfileName = eqPopUpButton.selectedItem!.title

    languageDropdown.removeAllItems()
    for (lang, _) in languages.sorted(by: { $0.key < $1.key }) {
      languageDropdown.addItem(withObjectValue: lang)
    }
    
    languageDropdown2.removeAllItems()
    // Добавляем пустой элемент первым для возможности перевода только на один язык
    languageDropdown2.addItem(withObjectValue: "")
    for (lang, _) in languages.sorted(by: { $0.key < $1.key }) {
      languageDropdown2.addItem(withObjectValue: lang)
    }
    
    let defaultIndex = languageDropdown.indexOfItem(withObjectValue: selectedLanguage.0)
    if defaultIndex >= 0 {
      languageDropdown.selectItem(at: defaultIndex)
    }
    
    // Устанавливаем метки для выпадающих списков, если они доступны
    if let languageLabel = languageLabel {
      languageLabel.stringValue = "Primary Language:"
    }
    if let languageLabel2 = languageLabel2 {
      languageLabel2.stringValue = "Secondary Language:"
    }
    
    // Добавляем обработчики изменений для выпадающих списков, если они доступны
    languageDropdown.target = self
    languageDropdown.action = #selector(languageDropdownChanged)
    if let languageDropdown2 = languageDropdown2 {
      languageDropdown2.target = self
      languageDropdown2.action = #selector(languageDropdown2Changed)
    }
    
    
    func observe(_ name: Notification.Name, block: @escaping (Notification) -> Void) {
      observers.append(NotificationCenter.default.addObserver(forName: name, object: player, queue: .main, using: block))
    }

    // notifications
    observe(.iinaTracklistChanged) { [unowned self] _ in
      self.withAllTableViews { view, _ in view.reloadData() }
    }
    observe(.iinaVIDChanged) { [unowned self] _ in self.videoTableView.reloadData() }
    observe(.iinaAIDChanged) { [unowned self] _ in self.audioTableView.reloadData() }
    observe(.iinaSIDChanged) { [unowned self] _ in
      self.subTableView.reloadData()
      self.secSubTableView.reloadData()
    }
    observe(.iinaSecondSubVisibilityChanged) { [unowned self] _ in secHideSwitch.state = player.info.isSecondSubVisible ? .on : .off }
    observe(.iinaSubVisibilityChanged) { [unowned self] _ in hideSwitch.state = player.info.isSubVisible ? .on : .off }
  }

  // MARK: - Right to Left Constraints

  /// Prepares the receiver for service after it has been loaded from an Interface Builder archive, or nib file.
  ///
  /// If the user interface layout direction is right to left then certain layout constraints that assume a left to right layout will need to be
  /// replaced. That will be handled by the `viewWillLayout` method. This method will disable these constraints to avoid triggering
  /// constraint errors before the constraints can be replaced.
  override func awakeFromNib() {
    super.awakeFromNib()
    guard speedSlider.userInterfaceLayoutDirection == .rightToLeft else { return }
    NSLayoutConstraint.deactivate([
      speedSlider1xLabelCenterXConstraint,
      speedSlider4xLabelCenterXConstraint,
      speedSlider1xLabelPrevLabelConstraint,
      speedSlider4xLabelPrevLabelConstraint,
      speedSlider16xLabelPrevLabelConstraint])
  }

  /// Calculate the constraint multiplier for a speed slider label.
  ///
  /// This method calculates the appropriate multiplier to use in a
  /// [centerX](https://developer.apple.com/documentation/uikit/nslayoutconstraint/attribute/centerx)
  /// constraint for a text field that sits under the speed slider and displays the speed associated with a particular tick mark.
  /// - Parameter speed: Playback speed the label indicates.
  /// - Returns: Multiplier to use in the constraint.
  private func calculateSliderLabelMultiplier(speed: Double) -> CGFloat {
    let tickIndex = Int(convertSpeedToSliderValue(speedSlider.closestTickMarkValue(toValue: speed)))
    let tickRect = speedSlider.rectOfTickMark(at: tickIndex)
    let tickCenterX = tickRect.origin.x + tickRect.width / 2
    let containerViewX = speedSlider.frame.origin.x + tickCenterX
    return containerViewX / speedSliderContainerView.frame.width
  }

  /// Called just before the `layout()` method of the view controller's view is called.
  ///
  /// If the user interface layout direction is right to left then this method will replace certain layout constraints with ones that properly
  /// position the reversed views.
  override func viewWillLayout() {
    // When the layout is right to left the first time this method is called the views will not have
    // been reversed. Once the views have been repositioned this method will be called again. Must
    // wait for that to happen before adjusting constraints to avoid triggering constraint errors.
    // Detect this based on the order of the speed slider labels.
    guard speedSliderContainerView.userInterfaceLayoutDirection == .rightToLeft,
          speedSlider16xLabel.frame.origin.x < speedSlider0_25xLabel.frame.origin.x else {
      super.viewWillLayout()
      return
    }

    // Deactivate the layout constraints that will be replaced.
    NSLayoutConstraint.deactivate([
      speedSlider1xLabelCenterXConstraint,
      speedSlider4xLabelCenterXConstraint,
      speedSlider1xLabelPrevLabelConstraint,
      speedSlider4xLabelPrevLabelConstraint,
      speedSlider16xLabelPrevLabelConstraint])

    // The multiplier in the constraints that position the 1x and 4x labels must be changed to
    // reflect the reversed views.
    speedSlider1xLabelCenterXConstraint = NSLayoutConstraint(
      item: speedSlider1xLabel as Any, attribute: .centerX, relatedBy: .equal, toItem: speedSlider,
      attribute: .right, multiplier: calculateSliderLabelMultiplier(speed: 1), constant: 0)
    speedSlider4xLabelCenterXConstraint = NSLayoutConstraint(
      item: speedSlider4xLabel as Any, attribute: .centerX, relatedBy: .equal, toItem: speedSlider,
      attribute: .right, multiplier: calculateSliderLabelMultiplier(speed: 4), constant: 0)

    // The constraints that impose an order on the labels must be changed to reflect the reversed
    // views.
    speedSlider1xLabelPrevLabelConstraint = NSLayoutConstraint(
      item: speedSlider1xLabel as Any, attribute: .right, relatedBy: .lessThanOrEqual,
      toItem: speedSlider0_25xLabel, attribute: .left, multiplier: 1, constant: 0)
    speedSlider4xLabelPrevLabelConstraint = NSLayoutConstraint(
      item: speedSlider4xLabel as Any, attribute: .right, relatedBy: .lessThanOrEqual,
      toItem: speedSlider1xLabel, attribute: .left, multiplier: 1, constant: 0)
    speedSlider16xLabelPrevLabelConstraint = NSLayoutConstraint(
      item: speedSlider16xLabel as Any, attribute: .right, relatedBy: .lessThanOrEqual,
      toItem: speedSlider4xLabel, attribute: .left, multiplier: 1, constant: 0)

    NSLayoutConstraint.activate([
      speedSlider1xLabelCenterXConstraint,
      speedSlider4xLabelCenterXConstraint,
      speedSlider1xLabelPrevLabelConstraint,
      speedSlider4xLabelPrevLabelConstraint,
      speedSlider16xLabelPrevLabelConstraint])
    super.viewWillLayout()
  }

  // MARK: - Validate UI

  /** Do synchronization*/
  override func viewDidAppear() {
    // image sub
    super.viewDidAppear()
    updateControlsState()
  }

  deinit {
    observers.forEach {
      NotificationCenter.default.removeObserver($0)
    }
  }

  private func updateControlsState() {
    updateVideoTabControl()
    updateAudioTabControl()
    updateSubTabControl()
    updateVideoEqState()
    updateAudioEqState()
  }

  /// Return the slider value that represents the given playback speed.
  /// - Parameter speed: Playback speed.
  /// - Returns: Appropriate slider value.
  private func convertSpeedToSliderValue(_ speed: Double) -> Double {
    log(speed / AppData.minSpeed) / log(AppData.maxSpeed / AppData.minSpeed) * sliderSteps
  }

  private func updateVideoTabControl() {
    if let index = AppData.aspectsInPanel.firstIndex(of: player.info.unsureAspect) {
      aspectSegment.selectedSegment = index
    } else {
      aspectSegment.selectedSegment = -1
    }
    if let index = AppData.cropsInPanel.firstIndex(of: player.info.unsureCrop) {
      cropSegment.selectedSegment = index
    } else {
      // Select last segment ("Custom...")
      cropSegment.selectedSegment = cropSegment.segmentCount - 1
    }
    rotateSegment.selectSegment(withTag: AppData.rotations.firstIndex(of: player.info.rotation) ?? -1)

    hardwareDecodingSwitch.state = player.info.hwdecEnabled ? .on : .off
    deinterlaceSwitch.state = player.info.deinterlace ? .on : .off
    hdrSwitch.isEnabled = player.info.hdrAvailable
    hdrSwitch.state = (player.info.hdrAvailable && player.info.hdrEnabled) ? .on : .off
    
    // These strings are also contained in the strings file of this view. Remove these lines if the localization of these strings are complete enough.
    hardwareDecodingLabel.stringValue = NSLocalizedString("quicksetting.hwdec", comment: "Hardware Decoding")
    deinterlaceLabel.stringValue = NSLocalizedString("quicksetting.deinterlace", comment: "Deinterlace")
    hdrLabel.stringValue = NSLocalizedString("quicksetting.hdr", comment: "HDR")

    let speed = player.mpv.getDouble(MPVOption.PlaybackControl.speed)
    updateSpeed(to: speed)
  }

  private func updateAudioTabControl() {
    let audioDelay = player.mpv.getDouble(MPVOption.Audio.audioDelay)
    audioDelaySlider.doubleValue = audioDelay
    customAudioDelayTextField.doubleValue = audioDelay
    redraw(indicator: audioDelaySliderIndicator, constraint: audioDelaySliderConstraint, slider: audioDelaySlider, value: "\(customAudioDelayTextField.stringValue)s")
  }

  private func updateSubTabControl() {
    hideSwitch.state = player.info.isSubVisible ? .on : .off
    secHideSwitch.state = player.info.isSecondSubVisible ? .on : .off

    if let currSub = player.info.currentTrack(.sub) {
      // FIXME: CollorWells cannot be disable?
      let enableTextSettings = !(currSub.isAssSub || currSub.isImageSub)
      [subTextColorWell, subTextSizePopUp, subTextBgColorWell, subTextBorderColorWell, subTextBorderWidthPopUp, subTextFontBtn].forEach { $0.isEnabled = enableTextSettings }
    }

    let isPrimary = (subSegmentedControl.selectedSegment == 0)
    let delayOption = isPrimary ? MPVOption.Subtitles.subDelay : MPVOption.Subtitles.secondarySubDelay
    let subDelay = player.mpv.getDouble(delayOption)
    subDelaySlider.doubleValue = subDelay
    customSubDelayTextField.doubleValue = subDelay
    redraw(indicator: subDelaySliderIndicator, constraint: subDelaySliderConstraint, slider: subDelaySlider, value: "\(customSubDelayTextField.stringValue)s")

    let posOption = isPrimary ? MPVOption.Subtitles.subPos : MPVOption.Subtitles.secondarySubPos
    let currSubPos = player.mpv.getInt(posOption)
    subPosSlider.intValue = Int32(currSubPos)

    let currSubScale = player.mpv.getDouble(MPVOption.Subtitles.subScale).clamped(to: 0.1...10)
    let displaySubScale = Utility.toDisplaySubScale(fromRealSubScale: currSubScale)
    subScaleSlider.doubleValue = displaySubScale + (displaySubScale > 0 ? -1 : 1)

    let fontSize = player.mpv.getInt(MPVOption.Subtitles.subFontSize)
    subTextSizePopUp.selectItem(withTitle: fontSize.description)

    let borderWidth = player.mpv.getDouble(MPVOption.Subtitles.subBorderSize)
    subTextBorderWidthPopUp.selectItem(at: -1)
    subTextBorderWidthPopUp.itemArray.forEach { item in
      if borderWidth == Double(item.title) {
        subTextBorderWidthPopUp.select(item)
      }
    }
  }

  private func updateVideoEqState() {
    brightnessSlider.intValue = Int32(player.info.brightness)
    contrastSlider.intValue = Int32(player.info.contrast)
    saturationSlider.intValue = Int32(player.info.saturation)
    gammaSlider.intValue = Int32(player.info.gamma)
    hueSlider.intValue = Int32(player.info.hue)
  }

  private func updateAudioEqState() {
    if let filter = player.info.audioEqFilter {
      guard let eqString = Regex("\\[(.+?)\\]").captures(in: filter.stringFormat)[at: 1] else { return }
      let filters = eqString.split(separator: ",")
      zip(filters, eqSliders).forEach { (filter, slider) in
        if let gain = filter.split(separator: "=").last {
          slider.doubleValue = Double(gain) ?? 0
        } else {
          slider.doubleValue = 0
        }
      }
    } else {
      eqSliders.forEach { $0.doubleValue = 0 }
    }
  }

  private func switchToTab(_ tab: TabViewType) {
    guard isViewLoaded else { return }
    currentTab = tab
    tabView.selectTabViewItem(at: tab.buttonTag)
    updateTabActiveStatus()
    reload()
  }

  private func updateTabActiveStatus() {
    let currentTag = currentTab.buttonTag
    [videoTabBtn, audioTabBtn, subTabBtn].forEach { btn in
      let isActive = currentTag == btn!.tag
      btn!.contentTintColor = isActive ? .sidebarTabTintActive : .sidebarTabTint
    }
  }

  func reload() {
    guard isViewLoaded else { return }
    switch currentTab {
    case .audio:
      audioTableView.reloadData()
      updateAudioTabControl()
      updateAudioEqState()
    case .video:
      videoTableView.reloadData()
      updateVideoTabControl()
      updateVideoEqState()
    case .sub:
      subTableView.reloadData()
      secSubTableView.reloadData()
      updateSubTabControl()
    }
  }

  func setHdrAvailability(to available: Bool) {
    player.info.hdrAvailable = available
    if isViewLoaded {
      hdrSwitch.isEnabled = available
      hdrSwitch.state = (available && player.info.hdrEnabled) ? .on : .off
    }
  }

  // MARK: - Switch tab

  /** Switch tab (call from other objects) */
  func pleaseSwitchToTab(_ tab: TabViewType) {
    if isViewLoaded {
      switchToTab(tab)
    } else {
      // cache the request
      pendingSwitchRequest = tab
    }
  }

  // MARK: - NSTableView delegate

  func numberOfRows(in tableView: NSTableView) -> Int {
    if tableView == videoTableView {
      return player.info.videoTracks.count + 1
    } else if tableView == audioTableView {
      return player.info.audioTracks.count + 1
    } else if tableView == subTableView || tableView == secSubTableView {
      return player.info.$subTracks.withLock { $0.count + 1 }
    } else {
      return 0
    }
  }

  func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
    // get track according to tableview
    // row=0: <None> row=1~: tracks[row-1]
    let track: MPVTrack?
    let activeId: Int
    let columnName = tableColumn?.identifier
    if tableView == videoTableView {
      track = row == 0 ? nil : player.info.videoTracks[at: row-1]
      activeId = player.info.vid!
    } else if tableView == audioTableView {
      track = row == 0 ? nil : player.info.audioTracks[at: row-1]
      activeId = player.info.aid!
    } else if tableView == subTableView {
      track = row == 0 ? nil : player.info.subTracks[at: row-1]
      activeId = player.info.sid!
    } else if tableView == secSubTableView {
      track = row == 0 ? nil : player.info.subTracks[at: row-1]
      activeId = player.info.secondSid!
    } else {
      return nil
    }
    // return track data
    if columnName == .isChosen {
      let isChosen = track == nil ? (activeId == 0) : (track!.id == activeId)
      return isChosen ? Constants.String.dot : ""
    } else if columnName == .trackName {
      return track?.infoString ?? Constants.String.trackNone
    } else if columnName == .trackId {
      return track?.idString
    }
    return nil
  }

  func tableViewSelectionDidChange(_ notification: Notification) {
    withAllTableViews { (view, type) in
      if view.numberOfSelectedRows > 0 {
        // note that track ids start from 1
        let subId = view.selectedRow > 0 ? player.info.trackList(type)[view.selectedRow-1].id : 0
        self.player.setTrack(subId, forType: type)
        view.deselectAll(self)
      }
    }
    // Revalidate layout and controls
    updateControlsState()
  }

  private func withAllTableViews(_ block: (NSTableView, MPVTrack.TrackType) -> Void) {
    block(audioTableView, .audio)
    block(subTableView, .sub)
    block(secSubTableView, .secondSub)
    block(videoTableView, .video)
  }

  private func withAllAudioEqSliders(_ block: (NSSlider) -> Void) {
    eqSliders.forEach {
      block($0)
    }
  }

  // MARK: - Actions

  // MARK: Tab buttons

  @IBAction func tabBtnAction(_ sender: NSButton) {
    switchToTab(.init(buttonTag: sender.tag))
  }

  // MARK: Video tab

  @IBAction func aspectChangedAction(_ sender: NSSegmentedControl) {
    let aspect = AppData.aspectsInPanel[sender.selectedSegment]
    player.setVideoAspect(aspect)
    player.sendOSD(.aspect(aspect))
  }

  @IBAction func cropChangedAction(_ sender: NSSegmentedControl) {
    if sender.selectedSegment == sender.segmentCount - 1 {
      // User clicked on "Custom...": show custom crop UI
      mainWindow.hideSideBar {
        self.mainWindow.enterInteractiveMode(.crop, selectWholeVideoByDefault: true)
      }
    } else {
      let cropStr = AppData.cropsInPanel[sender.selectedSegment]
      player.setCrop(fromString: cropStr)
      player.sendOSD(.crop(cropStr))
    }
  }

  @IBAction func rotationChangedAction(_ sender: NSSegmentedControl) {
    let value = AppData.rotations[sender.selectedSegment]
    player.setVideoRotate(value)
    player.sendOSD(.rotate(value))
  }

  @IBAction func customAspectEditFinishedAction(_ sender: AnyObject?) {
    let value = customAspectTextField.stringValue
    if value != "" {
      aspectSegment.setSelected(false, forSegment: aspectSegment.selectedSegment)
      player.setVideoAspect(value)
      player.sendOSD(.aspect(value))
    }
  }

  @IBAction func hardwareDecodingAction(_ sender: NSSwitch) {
    player.toggleHardwareDecoding(sender.state == .on)
  }
  
  @IBAction func deinterlaceAction(_ sender: NSSwitch) {
    player.toggleDeinterlace(sender.state == .on)
  }
  
  @IBAction func hdrAction(_ sender: NSSwitch) {
    self.player.info.hdrEnabled = sender.state == .on
    self.player.refreshEdrMode()
  }

  private func redraw(indicator: NSTextField, constraint: NSLayoutConstraint, slider: NSSlider, value: String) {
    indicator.stringValue = value
    let offset: CGFloat = 6
    let sliderInnerWidth = slider.frame.width - offset * 2
    constraint.constant = offset + sliderInnerWidth * CGFloat((slider.doubleValue - slider.minValue) / (slider.maxValue - slider.minValue))
    view.layout()
  }

  @IBAction func resetSpeedAction(_ sender: AnyObject) {
    player.setSpeed(1.0)
  }

  @IBAction func speedChangedAction(_ sender: NSSlider) {
    // Each step is 64^(1/24)
    //   0       1   ..    7      8      9   ..   24
    // 0.250x 0.297x .. 0.841x 1.000x 1.189x .. 16.00x
    let eventType = NSApp.currentEvent!.type
    if eventType == .leftMouseDown {
      sender.allowsTickMarkValuesOnly = true
    }
    if eventType == .leftMouseUp {
      sender.allowsTickMarkValuesOnly = false
    }
    let sliderValue = sender.doubleValue
    // Attempt to round speed to 2 decimal places. If user is using the slider, any more
    // precision than that is just a distraction
    let newSpeed = (AppData.minSpeed * pow(AppData.maxSpeed / AppData.minSpeed, sliderValue / sliderSteps)).roundedTo2Decimals()
    updateSpeed(to: newSpeed)
  }

  @IBAction func customSpeedEditFinishedAction(_ sender: NSTextField) {
    if sender.stringValue.isEmpty {
      sender.stringValue = "1"
    }
    /// Unfortunately, the text field has not applied validation/formatting to the number at this point.
    /// We will do that manually via `constrainSpeed`.
    updateSpeed(to: sender.doubleValue)
    if let window = sender.window {
      window.makeFirstResponder(window.contentView)
    }
  }

  /// Ensure that the given `Double` is a speed which is valid for mpv.
  ///
  /// - This is necessary because libmpv cannot be relied on to report the correct number & will reply
  /// with a property change event which echoes the number which was submitted, even if it is not the
  /// same as the number which mpv is actually using (it will internally round the number to 6 digits
  /// after the decimal but tell us that it used the non-rounded number).
  /// - `NumberFormatter` doesn't provide APIs to validate or correct an `NSNumber`.
  /// But we can get the same effect by converting to a `String` and back again.
  private func constrainSpeed(_ inputSpeed: Double) -> Double {
    let newSpeedString: String = speedFormatter.string(from: inputSpeed as NSNumber) ?? "1"
    return Double(truncating: speedFormatter.number(from: newSpeedString)!)
  }

  private func updateSpeed(to inputSpeed: Double) {
    let newSpeed = constrainSpeed(inputSpeed)
    speedSlider.doubleValue = convertSpeedToSliderValue(newSpeed)
    customSpeedTextField.doubleValue = newSpeed
    speedResetBtn.isHidden = newSpeed == 1.0
    if player.info.playSpeed != newSpeed {
      player.setSpeed(newSpeed)
    }
    /// Use `customSpeedTextField.stringValue` to take advantage of its formatter
    /// (e.g. `16` will be displayed instead of `16.0`)
    redraw(indicator: speedSliderIndicator, constraint: speedSliderConstraint, slider: speedSlider, value: "\(customSpeedTextField.stringValue)x")
  }

  @IBAction func equalizerSliderAction(_ sender: NSSlider) {
    let type: PlayerCore.VideoEqualizerType
    switch sender {
    case brightnessSlider:
      type = .brightness
    case contrastSlider:
      type = .contrast
    case saturationSlider:
      type = .saturation
    case gammaSlider:
      type = .gamma
    case hueSlider:
      type = .hue
    default:
      return
    }
    player.setVideoEqualizer(forOption: type, value: Int(sender.intValue))
  }

  // use tag for buttons
  @IBAction func resetEqualizerBtnAction(_ sender: NSButton) {
    let type: PlayerCore.VideoEqualizerType
    let slider: NSSlider?
    switch sender.tag {
    case 0:
      type = .brightness
      slider = brightnessSlider
    case 1:
      type = .contrast
      slider = contrastSlider
    case 2:
      type = .saturation
      slider = saturationSlider
    case 3:
      type = .gamma
      slider = gammaSlider
    case 4:
      type = .hue
      slider = hueSlider
    default:
      return
    }
    player.setVideoEqualizer(forOption: type, value: 0)
    slider?.intValue = 0
  }

  // MARK: Audio tab

  @IBAction func loadExternalAudioAction(_ sender: NSButton) {
    let currentDir = player.info.currentURL?.deletingLastPathComponent()
    Utility.quickOpenPanel(
      title: "Load external audio file",
      chooseDir: false,
      dir: currentDir,
      sheetWindow: player.currentWindow,
      allowedFileTypes: Utility.playableFileExt
    ) { url in
      self.player.loadExternalAudioFile(url)
      self.audioTableView.reloadData()
    }
  }

  @IBAction func audioDelayChangedAction(_ sender: NSSlider) {
    let eventType = NSApp.currentEvent!.type
    if eventType == .leftMouseDown {
      sender.allowsTickMarkValuesOnly = true
    }
    if eventType == .leftMouseUp {
      sender.allowsTickMarkValuesOnly = false
    }
    let sliderValue = sender.doubleValue
    customAudioDelayTextField.doubleValue = sliderValue
    redraw(indicator: audioDelaySliderIndicator, constraint: audioDelaySliderConstraint, slider: audioDelaySlider, value: "\(customAudioDelayTextField.stringValue)s")
    if let event = NSApp.currentEvent {
      if event.type == .leftMouseUp {
        player.setAudioDelay(sliderValue)
      }
    }
  }

  @IBAction func customAudioDelayEditFinishedAction(_ sender: NSTextField) {
    if sender.stringValue.isEmpty {
      sender.stringValue = "0"
    }
    let value = sender.doubleValue
    player.setAudioDelay(value)
    audioDelaySlider.doubleValue = value
    redraw(indicator: audioDelaySliderIndicator, constraint: audioDelaySliderConstraint, slider: audioDelaySlider, value: "\(sender.stringValue)s")
  }

  func applyEQ(_ profile: EQProfile) {
    zip(eqSliders, profile.gains).forEach { (slider, gain) in
      slider.doubleValue = gain
    }
    player.setAudioEq(fromGains: profile.gains)
  }



  @IBAction func audioEqSliderAction(_ sender: NSSlider) {
    player.setAudioEq(fromGains: eqSliders.map { $0.doubleValue })
    eqPopUpButton.selectItem(withTag: eqCustomMenuItemTag)
  }

  // MARK: Sub tab

  @IBAction func hideSubAction(_ sender: NSSwitch) {
    player.toggleSubVisibility()
  }

  @IBAction func hideSecSubAction(_ sender: NSSwitch) {
    player.toggleSecondSubVisibility()
  }

  @IBAction func loadExternalSubAction(_ sender: NSSegmentedControl) {
    if sender.selectedSegment == 0 {
      let currentDir = player.info.currentURL?.deletingLastPathComponent()
      Utility.quickOpenPanel(title: "Load external subtitle", chooseDir: false, dir: currentDir,
                             sheetWindow: player.currentWindow, allowedFileTypes: Utility.supportedFileExt[.sub]) { url in
        // set a delay
        self.player.loadExternalSubFile(url, delay: true)
        self.subTableView.reloadData()
        self.secSubTableView.reloadData()
      }
    } else if sender.selectedSegment == 1 {
      showSubChooseMenu(forView: sender)
    }
  }

  func showSubChooseMenu(forView view: NSView, showLoadedSubs: Bool = false) {
    let activeSubs = player.info.trackList(.sub) + player.info.trackList(.secondSub)
    let menu = NSMenu()
    menu.autoenablesItems = false
    // loaded subtitles
    if showLoadedSubs {
      if player.info.subTracks.isEmpty {
        menu.addItem(withTitle: NSLocalizedString("subtrack.no_loaded", comment: "No subtitles loaded"), enabled: false)
      } else {
        menu.addItem(withTitle: NSLocalizedString("track.none", comment: "<None>"),
                     action: #selector(self.chosenSubFromMenu(_:)), target: self,
                     stateOn: player.info.sid == 0 ? true : false)

        for sub in player.info.subTracks {
          menu.addItem(withTitle: sub.readableTitle,
                       action: #selector(self.chosenSubFromMenu(_:)),
                       target: self,
                       obj: sub,
                       stateOn: sub.id == player.info.sid ? true : false)
        }
      }
      menu.addItem(NSMenuItem.separator())
    }
    // external subtitles
    let addMenuItem = { (sub: FileInfo) -> Void in
      let isActive = !showLoadedSubs && activeSubs.contains { $0.externalFilename == sub.path }
      menu.addItem(withTitle: "\(sub.filename).\(sub.ext)",
                   action: #selector(self.chosenSubFromMenu(_:)),
                   target: self,
                   obj: sub,
                   stateOn: isActive ? true : false)

    }
    if player.info.currentSubsInfo.isEmpty {
      menu.addItem(withTitle: NSLocalizedString("subtrack.no_external", comment: "No external subtitles found"),
                   enabled: false)
    } else {
      if let videoInfo = player.info.currentVideosInfo.first(where: { $0.url == player.info.currentURL }),
        !videoInfo.relatedSubs.isEmpty {
        videoInfo.relatedSubs.forEach(addMenuItem)
        menu.addItem(NSMenuItem.separator())
      }
      player.info.currentSubsInfo.sorted { (f1, f2) in
        return f1.filename.localizedStandardCompare(f2.filename) == .orderedAscending
      }.forEach(addMenuItem)
    }
    NSMenu.popUpContextMenu(menu, with: NSApp.currentEvent!, for: view)
  }

  @objc func chosenSubFromMenu(_ sender: NSMenuItem) {
    if let fileInfo = sender.representedObject as? FileInfo {
      player.loadExternalSubFile(fileInfo.url)
    } else if let sub = sender.representedObject as? MPVTrack {
      player.setTrack(sub.id, forType: .sub)
    } else {
      player.setTrack(0, forType: .sub)
    }
  }

  func readSRTFile(at path: String) -> String? {
      let fileURL = URL(fileURLWithPath: path)
      do {
          // Read the content of the file
          let fileContents = try String(contentsOf: fileURL, encoding: .utf8)
          return fileContents
      } catch {
          // Handle the error, e.g., file not found or unreadable
          print("Failed to read file: \(error)")
          return nil
      }
  }
  
  func parseSRT(_ srtContent: String) -> [SubtitleBlock] {
      var blocks = [SubtitleBlock]()
      
      // Normalize line endings by replacing all variations with "\n"
      let normalizedContent = srtContent.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
      
      // Split the content into blocks separated by double newlines
      let components = normalizedContent.components(separatedBy: "\n\n")
      
      for component in components {
          let lines = component.split(separator: "\n", omittingEmptySubsequences: false) // Split by single newlines
          if lines.count >= 3, let index = Int(lines[0]) {
              let timestamp = String(lines[1])
              let text = lines[2...].joined(separator: " ") // Combine the subtitle text, preserving multiple lines
              blocks.append(SubtitleBlock(index: index, timestamp: timestamp, text: text))
          }
      }
      
      return blocks
  }

  func groupSubtitleBlocks(_ blocks: [SubtitleBlock], maxChars: Int = 6000) -> [[SubtitleBlock]] {
      var groups = [[SubtitleBlock]]()
      var currentGroup = [SubtitleBlock]()
      var currentLength = 0

      for block in blocks {
          let blockLength = block.text.count // Only count the characters in the text

          // Check if adding this block exceeds the maximum characters
          if currentLength + blockLength > maxChars {
              groups.append(currentGroup)
              currentGroup = [block]
              currentLength = blockLength // Start new group with this block
          } else {
              currentGroup.append(block)
              currentLength += blockLength
          }
      }

      // Add the final group if there are any remaining blocks
      if !currentGroup.isEmpty {
          groups.append(currentGroup)
      }

      return groups
  }

  func translateGroup(_ blocks: [SubtitleBlock], source: String, target: String, completion: @escaping (Result<[String], Error>) -> Void) {
      // Собираем только текст субтитров в виде массива
      let textsToTranslate = blocks.map { $0.text }
      
      guard let url = URL(string: "https://translate-pa.googleapis.com/v1/translateHtml") else {
          completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
          return
      }

      var request = URLRequest(url: url)
      request.httpMethod = "POST"
      request.addValue("application/json+protobuf", forHTTPHeaderField: "Content-Type")
      request.addValue("AIzaSyATBXajvzQLTDHEQbcpq0Ihe0vWDHmO520", forHTTPHeaderField: "x-goog-api-key") // Добавляем API-ключ

      // Форматируем тело запроса в виде массива строк
      let body: [Any] = [
        [textsToTranslate, "auto", target],
        "te"  // флаг "te" как в примере запроса
      ]

      do {
        let requestBody = try JSONSerialization.data(withJSONObject: body, options: .prettyPrinted)
        if let jsonString = String(data: requestBody, encoding: .utf8) {
            print("Request Body:\n\(jsonString)")
        }
        request.httpBody = requestBody
      } catch {
          completion(.failure(error))
          return
      }

      let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let error = error {
              completion(.failure(error))
              return
          }

          // Проверяем код ответа
          guard let httpResponse = response as? HTTPURLResponse else {
              completion(.failure(NSError(domain: "No response", code: -1, userInfo: nil)))
              return
          }

          if !(200...299).contains(httpResponse.statusCode) {
              if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                  print("Response Body: \(responseBody)")
              }
              completion(.failure(NSError(domain: "Invalid response", code: httpResponse.statusCode, userInfo: nil)))
              return
          }

          guard let data = data else {
              completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
              return
          }

          // Обрабатываем JSON-ответ
          do {
              if let json = try JSONSerialization.jsonObject(with: data) as? [[String]] {
                  let translatedTexts = json[0] // Первый элемент массива содержит переведённые строки
                  completion(.success(translatedTexts))
              } else {
                  completion(.failure(NSError(domain: "Unexpected response format", code: -1, userInfo: nil)))
              }
          } catch {
              completion(.failure(error))
          }
      }

      task.resume()
  }

  func translateSRT(_ blocks: [SubtitleBlock], source: String, target: String, maxWorkers: Int = 5, completion: @escaping ([SubtitleBlock]) -> Void) {
      let groups = groupSubtitleBlocks(blocks)
      let totalGroups = groups.count // Total groups to track progress
      var completedGroups = 0 // Track the completed groups

      let queue = OperationQueue()
      queue.maxConcurrentOperationCount = maxWorkers
      
      var translatedGroups = [(index: Int, blocks: [SubtitleBlock])]()
      let dispatchGroup = DispatchGroup()
      let syncQueue = DispatchQueue(label: "com.iina.translateSRT.syncQueue") // Serial queue for thread safety
      
      // Track start time to calculate elapsed and estimated remaining time
      let startTime = Date()

      for (groupIndex, group) in groups.enumerated() {
          dispatchGroup.enter()
          queue.addOperation {
            self.translateGroup(group, source: source, target: target) { result in
                  switch result {
                  case .success(let translatedTexts):
                      var translatedBlocksInGroup = [SubtitleBlock]()
                      for (i, translatedText) in translatedTexts.enumerated() {
                          let originalBlock = group[i]
                          let translatedBlock = SubtitleBlock(index: originalBlock.index, timestamp: originalBlock.timestamp, text: translatedText)
                          translatedBlocksInGroup.append(translatedBlock)
                      }
                      
                      // Add translated group along with its index to maintain order in a thread-safe manner
                      syncQueue.async {
                          translatedGroups.append((index: groupIndex, blocks: translatedBlocksInGroup))
                      }
                  case .failure(let error):
                      print("Translation failed: \(error)")
                      self.player.sendOSD(.translationFailed(error.localizedDescription))
                  }
                  
                  // Update completed groups and log progress
                  syncQueue.async {
                      completedGroups += 1
                      
                      // Calculate elapsed time
                      let elapsedTime = Date().timeIntervalSince(startTime)
                      
                      // Estimate remaining time
                      let estimatedTotalTime = (elapsedTime / Double(completedGroups)) * Double(totalGroups)
                      let remainingTime = estimatedTotalTime - elapsedTime
                    
                      // Log progress
                      print("Progress: \(completedGroups)/\(totalGroups) groups done.")
                      print("Elapsed time: \(elapsedTime.formattedTime()), Estimated remaining time: \(remainingTime.formattedTime())")
                    
                      self.player.sendOSD(.translating(completedGroups, totalGroups))
                  }

                  dispatchGroup.leave()
              }
          }
      }

      dispatchGroup.notify(queue: .main) {
          // Sort translated groups and flatten the array
          let sortedTranslatedBlocks = translatedGroups.sorted(by: { $0.index < $1.index }).flatMap({ $0.blocks })
          completion(sortedTranslatedBlocks)
      }
  }


  func rebuildSRT(from blocks: [SubtitleBlock]) -> String {
      return blocks.map { "\($0.index)\r\n\($0.timestamp)\r\n\($0.text)\r\n" }.joined(separator: "\r\n")
  }
  

  func findFFmpegPath() -> String? {
    // Проверка нескольких возможных путей к FFmpeg
    let possiblePaths = [
      "/opt/homebrew/bin/ffmpeg",
      "/usr/local/bin/ffmpeg",
      "/usr/bin/ffmpeg",
      "/bin/ffmpeg"
    ]
    
    // Сначала проверяем существование файлов
    for path in possiblePaths {
      if FileManager.default.fileExists(atPath: path) {
        Logger.log("Found FFmpeg at: \(path)")
        return path
      }
    }
    
    // Если не нашли, пытаемся найти через which
    let process = Process()
    let pipe = Pipe()
    
    process.launchPath = "/usr/bin/which"
    process.arguments = ["ffmpeg"]
    process.standardOutput = pipe
    
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      Logger.log("Failed to run which command for ffmpeg: \(error)", level: .error)
      return nil
    }
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    
    if let path = output, !path.isEmpty {
      Logger.log("Found FFmpeg via which: \(path)")
      return path
    }
    
    Logger.log("FFmpeg not found in system PATH", level: .error)
    return nil
  }
  
  func extractSubtitlesToMemory(ffmpegPath: String, videoPath: String, trackId: Int) -> String? {
    Logger.log("Attempting to extract subtitles from \(videoPath), track \(trackId)", level: .debug)
    
    // Декодируем URL-кодированные символы в пути
    guard let decodedPath = videoPath.removingPercentEncoding,
          let videoURL = URL(string: decodedPath) else {
      Logger.log("Failed to decode video path: \(videoPath)", level: .error)
      return nil
    }
    
    let videoPathLocal = videoURL.path
    
    Logger.log("Decoded video path: \(videoPathLocal)", level: .debug)
    
    // Проверяем, существует ли файл
    if !FileManager.default.fileExists(atPath: videoPathLocal) {
      Logger.log("Video file does not exist at path: \(videoPathLocal)", level: .error)
      return nil
    }
    
    Logger.log("Video file exists at path: \(videoPathLocal)", level: .debug)
    
    let process = Process()
    let pipe = Pipe()
    let errorPipe = Pipe()
    
    process.launchPath = ffmpegPath
    process.arguments = [
      "-i", videoPathLocal,
      "-map", "0:s:\(trackId-1)",
      "-c:s", "copy",
      "-f", "srt",
      "-y", // overwrite output without asking
      "-"
    ]
    
    process.standardOutput = pipe
    process.standardError = errorPipe
    
    Logger.log("FFmpeg command: \(ffmpegPath) \(process.arguments?.joined(separator: " ") ?? "")", level: .debug)
    
    do {
      try process.run()
      process.waitUntilExit()
    } catch {
      Logger.log("Failed to run FFmpeg process: \(error)", level: .error)
      return nil
    }
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    
    // Логируем ошибки FFmpeg
    if let error = String(data: errorData, encoding: .utf8), !error.isEmpty {
      Logger.log("FFmpeg error output: \(error)", level: .error)
    }
    
    let exitCode = process.terminationStatus
    if exitCode != 0 {
      Logger.log("FFmpeg exited with code: \(exitCode)", level: .error)
      return nil
    }
    
    let result = String(data: data, encoding: .utf8)
    
    if let result = result {
      let charCount = result.count
      Logger.log("Successfully extracted \(charCount) characters of subtitle text", level: .debug)
      
      // Проверяем, что результат не пустой и содержит данные субтитров
      if charCount > 0 && result.contains("-->") {
        Logger.log("Subtitle extraction successful, SRT format detected", level: .debug)
        return result
      } else {
        Logger.log("Extracted data appears to be empty or not in SRT format", level: .warning)
        return nil
      }
    } else {
      Logger.log("Failed to decode subtitle data", level: .error)
      return nil
    }
  }
  
  @IBAction func translateSubtitles(_ sender: Any) {
    guard let currentSub = player.info.subTracks.first(where: { $0.id == player.info.sid }) else {
      Logger.log("No current subtitle track found.")
      player.sendOSD(.translationFailed("No subtitle track found"))
      return
    }
    
    Logger.log("Starting subtitle translation for track: \(currentSub.id), type: \(currentSub.type)")
    
    let srtContent: String?
    
    if let filePath = currentSub.externalFilename {
      // external subtitles
      Logger.log("External subtitles detected: \(filePath)")
      
      // Read the subtitle file content
      guard let srtFileContent = readSRTFile(at: filePath) else {
          Logger.log("Failed to read the subtitle file at \(filePath).")
          player.sendOSD(.translationFailed("Failed to read subtitle file"))
          return
      }
      
      srtContent = srtFileContent
    } else {
      // internal subtitles
      Logger.log("Internal subtitles detected, track ID: \(currentSub.id)")
      
      guard let ffmpegPath = findFFmpegPath() else {
        Logger.log("FFmpeg not found. Please install it first.")
        player.sendOSD(.translationFailed("FFmpeg not found. Please install it first."))
        return
      }
      
      Logger.log("Using FFmpeg at: \(ffmpegPath)")
      
      // Проверяем, что у нас есть URL видео
      guard let videoURL = player.info.currentURL else {
        Logger.log("No current video URL available")
        player.sendOSD(.translationFailed("No video loaded"))
        return
      }
      
      // Проверяем, не является ли субтитр изображением
      if currentSub.isImageSub {
        Logger.log("Image-based subtitles cannot be translated")
        player.sendOSD(.translationFailed("Image-based subtitles cannot be translated"))
        return
      }
      
      // Извлекаем субтитры
      guard let extractedSubtitles = extractSubtitlesToMemory(
        ffmpegPath: ffmpegPath,
        videoPath: videoURL.absoluteString,
        trackId: currentSub.id
      ) else {
        Logger.log("Failed to extract internal subtitles.")
        player.sendOSD(.translationFailed("Failed to extract internal subtitles"))
        return
      }
      
      srtContent = extractedSubtitles
    }
    
    // Проверяем, что контент не пустой
    guard let srtContent = srtContent, !srtContent.isEmpty else {
      Logger.log("No subtitle content to translate")
      player.sendOSD(.translationFailed("No subtitle content found"))
      return
    }
    
    player.sendOSD(.startTranslation)
    
    // Парсим SRT
    let blocks = parseSRT(srtContent)
    Logger.log("Parsed \(blocks.count) subtitle blocks")
    
    // Проверяем, что есть блоки для перевода
    guard !blocks.isEmpty else {
      Logger.log("No valid subtitle blocks found")
      player.sendOSD(.translationFailed("No valid subtitle blocks found"))
      return
    }
    
    // Получаем выбранные языки
    let selectedLanguageName = languageDropdown.stringValue
    let selectedLanguageName2 = languageDropdown2.stringValue
    
    guard let selectedLanguageCode = languages[selectedLanguageName] else {
      Logger.log("Selected language code not found for \(selectedLanguageName)")
      player.sendOSD(.translationFailed("Invalid target language selected"))
      return
    }
    
    // Проверяем, выбран ли второй язык
    let selectedLanguageCode2 = languages[selectedLanguageName2]
    
    Logger.log("Translating to \(selectedLanguageName) (\(selectedLanguageCode))" + (selectedLanguageCode2 != nil ? " and \(selectedLanguageName2) (\(selectedLanguageCode2!))" : ""))
    
    // Асинхронная обработка переводов с синхронизацией
    let dispatchGroup = DispatchGroup()
    let syncQueue = DispatchQueue(label: "com.iina.translateSubtitles.syncQueue")
    
    var translatedBlocks1: [SubtitleBlock] = []
    var translatedBlocks2: [SubtitleBlock]?
    var translationErrors: [String] = []
    
    // Запускаем первый перевод
    dispatchGroup.enter()
    translateSRT(blocks, source: "auto", target: selectedLanguageCode, maxWorkers: 5) { blocks1 in
        syncQueue.async {
            translatedBlocks1 = blocks1
        }
        dispatchGroup.leave()
    }
    
    // Запускаем второй перевод, если он выбран
    if let languageCode2 = selectedLanguageCode2 {
        dispatchGroup.enter()
        translateSRT(blocks, source: "auto", target: languageCode2, maxWorkers: 5) { blocks2 in
            syncQueue.async {
                translatedBlocks2 = blocks2
            }
            dispatchGroup.leave()
        }
    }
    
    // Ждем завершения переводов
    dispatchGroup.notify(queue: .main) {
        // Проверяем, что первый перевод успешен
        if translatedBlocks1.isEmpty {
            Logger.log("First translation failed")
            self.player.sendOSD(.translationFailed("First translation failed"))
            return
        }
        
        // Сохраняем первый перевод (primary)
        let translatedSRT1 = self.rebuildSRT(from: translatedBlocks1)
        if let srtData1 = translatedSRT1.data(using: .utf8) {
            let originalFileName = self.player.info.currentURL?.deletingPathExtension().lastPathComponent ?? "video"
            
            if let savedUrl1 = self.saveSubtitle(data: srtData1, fileName: originalFileName, languageCode: selectedLanguageCode) {
                Logger.log("Saved primary subtitle to \(savedUrl1.path)")
                
                // Если есть второй перевод, сохраняем его
                if let languageCode2 = selectedLanguageCode2, let blocks2 = translatedBlocks2, !blocks2.isEmpty {
                    let translatedSRT2 = self.rebuildSRT(from: blocks2)
                    if let srtData2 = translatedSRT2.data(using: .utf8) {
                        if let savedUrl2 = self.saveSubtitle(data: srtData2, fileName: originalFileName, languageCode: languageCode2) {
                            Logger.log("Saved secondary subtitle to \(savedUrl2.path)")
                            
                            // Загружаем оба перевода в плеер
                            DispatchQueue.main.async {
                                self.player.loadExternalSubFile(savedUrl1)
                                self.player.loadExternalSubFile(savedUrl2)
                                
                                // Ждем немного, чтобы субтитры загрузились
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    // Находим ID только что загруженных субтитров
                                    if let primarySub = self.player.info.subTracks.last(where: { $0.externalFilename == savedUrl1.path }) {
                                        // Выбираем первый перевод для основных субтитров
                                        self.player.setTrack(primarySub.id, forType: .sub)
                                        Logger.log("Selected primary subtitle: \(primarySub.id) - \(primarySub.readableTitle)")
                                    }
                                    
                                    if let secondarySub = self.player.info.subTracks.last(where: { $0.externalFilename == savedUrl2.path }) {
                                        // Выбираем второй перевод для дополнительных субтитров
                                        self.player.setTrack(secondarySub.id, forType: .secondSub)
                                        Logger.log("Selected secondary subtitle: \(secondarySub.id) - \(secondarySub.readableTitle)")
                                    }
                                    
                                    // Обновляем таблицы
                                    self.subTableView.reloadData()
                                    self.secSubTableView.reloadData()
                                    
                                    self.player.sendOSD(.translatedSub("Both translations completed and selected"))
                                }
                            }
                        } else {
                            Logger.log("Failed to save the secondary translated subtitle.")
                            DispatchQueue.main.async {
                                self.player.sendOSD(.translationFailed("Failed to save secondary translation"))
                            }
                        }
                    } else {
                        Logger.log("Failed to convert the secondary translated SRT to data.")
                        DispatchQueue.main.async {
                            self.player.sendOSD(.translationFailed("Failed to convert secondary translation data"))
                        }
                    }
                } else {
                    // Если второго перевода нет, загружаем только первый
                    DispatchQueue.main.async {
                        self.player.loadExternalSubFile(savedUrl1)
                        
                        // Ждем немного, чтобы субтитры загрузились
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            // Находим ID только что загруженного субтитра
                            if let primarySub = self.player.info.subTracks.last(where: { $0.externalFilename == savedUrl1.path }) {
                                // Выбираем перевод для основных субтитров
                                self.player.setTrack(primarySub.id, forType: .sub)
                                Logger.log("Selected single subtitle: \(primarySub.id) - \(primarySub.readableTitle)")
                            }
                            
                            // Обновляем таблицы
                            self.subTableView.reloadData()
                            self.secSubTableView.reloadData()
                            
                            self.player.sendOSD(.translatedSub("Translation completed and selected"))
                        }
                    }
                }
            } else {
                Logger.log("Failed to save the primary translated subtitle.")
                DispatchQueue.main.async {
                    self.player.sendOSD(.translationFailed("Failed to save primary translation"))
                }
            }
        } else {
            Logger.log("Failed to convert the primary translated SRT to data.")
            DispatchQueue.main.async {
                self.player.sendOSD(.translationFailed("Failed to convert primary translation data"))
            }
        }
    }
  }
  
  func saveSubtitle(data: Data, fileName: String, languageCode: String) -> URL? {
      // Create the file name with the language code prefix
      let subFilename = "[\(languageCode.uppercased())] \(fileName).srt"
      
      // Attempt to save the file in the temp directory
      guard let url = data.saveToFolder(Utility.tempDirURL, filename: subFilename) else {
          Logger.log("Failed to save subtitle with language code: \(languageCode)")
          return nil
      }
      
      Logger.log("Saved subtitle file: \(url.path)")
      return url
  }
  
  @IBAction func searchOnlineAction(_ sender: AnyObject) {
    mainWindow.menuActionHandler.menuFindOnlineSub(.dummy)
  }

  @IBAction func subSegmentedControlAction(_ sender: NSSegmentedControl) {
    updateSubTabControl()
  }

  @IBAction func subDelayChangedAction(_ sender: NSSlider) {
    let eventType = NSApp.currentEvent!.type
    if eventType == .leftMouseDown {
      sender.allowsTickMarkValuesOnly = true
    }
    if eventType == .leftMouseUp {
      sender.allowsTickMarkValuesOnly = false
    }
    let sliderValue = sender.doubleValue
    customSubDelayTextField.doubleValue = sliderValue
    redraw(indicator: subDelaySliderIndicator, constraint: subDelaySliderConstraint, slider: subDelaySlider, value: "\(customSubDelayTextField.stringValue)s")
    if let event = NSApp.currentEvent {
      if event.type == .leftMouseUp {
        player.setSubDelay(sliderValue, forPrimary: subSegmentedControl.selectedSegment == 0)
      }
    }
  }

  @IBAction func customSubDelayEditFinishedAction(_ sender: NSTextField) {
    if sender.stringValue.isEmpty {
      sender.stringValue = "0"
    }
    let value = sender.doubleValue
    player.setSubDelay(value, forPrimary: subSegmentedControl.selectedSegment == 0)
    subDelaySlider.doubleValue = value
    redraw(indicator: subDelaySliderIndicator, constraint: subDelaySliderConstraint, slider: subDelaySlider, value: "\(sender.stringValue)s")
  }

  @IBAction func subScaleReset(_ sender: AnyObject) {
    player.setSubScale(1)
    subScaleSlider.doubleValue = 0
  }

  @IBAction func subPosSliderAction(_ sender: NSSlider) {
    player.setSubPos(Int(sender.intValue), forPrimary: subSegmentedControl.selectedSegment == 0)
  }

  @IBAction func subScaleSliderAction(_ sender: NSSlider) {
    let value = sender.doubleValue
    let mappedValue: Double, realValue: Double
    // map [-10, -1], [1, 10] to [-9, 9], bounds may change in future
    if value > 0 {
      mappedValue = round((value + 1) * 20) / 20
      realValue = mappedValue
    } else {
      mappedValue = round((value - 1) * 20) / 20
      realValue = 1 / mappedValue
    }
    player.setSubScale(realValue)
  }

  @IBAction func subTextColorAction(_ sender: AnyObject) {
    player.setSubTextColor(subTextColorWell.color.mpvColorString)
  }

  @IBAction func subTextSizeAction(_ sender: AnyObject) {
    if let selectedItem = subTextSizePopUp.selectedItem, let value = Double(selectedItem.title) {
      player.setSubTextSize(value)
    }
  }

  @IBAction func subTextBorderColorAction(_ sender: AnyObject) {
    player.setSubTextBorderColor(subTextBorderColorWell.color.mpvColorString)
  }

  @IBAction func subTextBorderWidthAction(_ sender: AnyObject) {
    if let selectedItem = subTextBorderWidthPopUp.selectedItem, let value = Double(selectedItem.title) {
      player.setSubTextBorderSize(value)
    }
  }

  @IBAction func subTextBgColorAction(_ sender: AnyObject) {
    player.setSubTextBgColor(subTextBgColorWell.color.mpvColorString)
  }

  @IBAction func subFontAction(_ sender: AnyObject) {
    Utility.quickFontPickerWindow() {
      self.player.setSubFont($0 ?? "")
    }
  }

  // MARK: - Language selection handlers
  
  @objc func languageDropdownChanged(_ sender: NSComboBox) {
    if let selectedLanguageName = sender.stringValue as String?,
       let languageCode = languages[selectedLanguageName] {
      selectedLanguage = (selectedLanguageName, languageCode)
      Logger.log("Primary language changed to: \(selectedLanguageName) (\(languageCode))")
    }
  }
  
  @objc func languageDropdown2Changed(_ sender: NSComboBox) {
    // Проверяем, что sender - это именно languageDropdown2
    if sender === languageDropdown2,
       let selectedLanguageName = sender.stringValue as String?,
       !selectedLanguageName.isEmpty,
       let languageCode = languages[selectedLanguageName] {
      selectedLanguage2 = (selectedLanguageName, languageCode)
      Logger.log("Secondary language changed to: \(selectedLanguageName) (\(languageCode))")
    } else {
      // Если выбран пустой элемент или язык не найден
      selectedLanguage2 = ("", "")
      Logger.log("Secondary language cleared")
    }
  }

}

extension QuickSettingViewController: NSMenuDelegate {
  private func promptAudioEQProfileName(isNewProfile: Bool) -> String? {
    let key = isNewProfile ? "eq.new_profile" : "eq.rename"
    let nameList = eqPopUpButton.itemArray
      .filter{ $0.tag == eqPresetProfileMenuItemTag || $0.tag == eqUserDefinedProfileMenuItemTag }
      .map{ $0.title }
    let validator: Utility.InputValidator<String> = { input in
      if input.isEmpty {
        return .valueIsEmpty
      }
      if nameList.contains( where: { $0 == input } ) {
        return .valueAlreadyExists
      } else {
        return .ok
      }
    }
    var inputString: String?
    Utility.quickPromptPanel(key, validator: validator, callback: { inputString = $0 })
    return inputString
  }
  
  func findItem(_ name: String, _ tag: Int = eqUserDefinedProfileMenuItemTag) -> NSMenuItem? {
    return eqPopUpButton.itemArray.filter{ $0.tag == tag }.first { $0.title == name }
  }

  @IBAction func eqPopUpButtonAction(_ sender: NSPopUpButton) {
    let tag = sender.selectedTag()
    let name = sender.titleOfSelectedItem
    let representedObject = sender.selectedItem?.representedObject as? String
    switch tag {
    case eqSaveMenuItemTag:
      if let inputString = promptAudioEQProfileName(isNewProfile: true) {
        let newProfile = EQProfile(fromCurrentSliders: eqSliders)
        userEQs[inputString] = newProfile
        menuNeedsUpdate(eqPopUpButton.menu!)
        eqPopUpButton.select(findItem(inputString))
        lastUsedProfileName = inputString
      } else {
        eqPopUpButton.selectItem(withTag: eqCustomMenuItemTag)
      }
    case eqRenameMenuItemTag:
      if let inputString = promptAudioEQProfileName(isNewProfile: false) {
        let profile = userEQs.removeValue(forKey: lastUsedProfileName)
        userEQs[inputString] = profile
        menuNeedsUpdate(eqPopUpButton.menu!)
        eqPopUpButton.select(findItem(inputString))
        lastUsedProfileName = inputString
      } else {
        eqPopUpButton.select(findItem(lastUsedProfileName))
      }
    case eqDeleteMenuItemTag:
      userEQs.removeValue(forKey: lastUsedProfileName)
      menuNeedsUpdate(eqPopUpButton.menu!)
      eqPopUpButton.selectItem(withTag: eqCustomMenuItemTag)
    case eqCustomMenuItemTag:
      lastUsedProfileName = sender.selectedItem!.title
    case eqPresetProfileMenuItemTag:
      guard let preset = presetEQs.first(where: { $0.localizationKey == representedObject }) else { break }
      lastUsedProfileName = preset.name
      applyEQ(preset)
    default: // user defined EQ Profiles
      guard let pair = userEQs.first(where: { $0.0 == name }) else { break }
      lastUsedProfileName = pair.0
      applyEQ(pair.1)
    }
  }

  func menuNeedsUpdate(_ menu: NSMenu) {
    let tag = eqPopUpButton.selectedTag()
    let saveItem = menu.item(withTag: eqSaveMenuItemTag)!
    let editingItems = [menu.item(withTag: eqRenameMenuItemTag)!, menu.item(withTag: eqDeleteMenuItemTag)!]

    editingItems.forEach { $0.isEnabled = (tag == eqUserDefinedProfileMenuItemTag) }
    saveItem.isEnabled = (tag == eqCustomMenuItemTag)

    let selectedName = eqPopUpButton.titleOfSelectedItem!
    let selectedTag = eqPopUpButton.selectedTag()
    var items = menu.items
    items.removeAll { $0.tag == eqUserDefinedProfileMenuItemTag }
    if !userEQs.isEmpty {
      items.append(NSMenuItem.separator())
    }
    menu.items = items
    userEQs.forEach { (name, eq) in
      menu.addItem(withTitle: name, tag: eqUserDefinedProfileMenuItemTag)
    }
    eqPopUpButton.select(findItem(selectedName, selectedTag))
    eqPopUpButton.itemArray.forEach { $0.state = .off }
    eqPopUpButton.selectedItem?.state = .on
  }
}

class QuickSettingView: NSView {

  override func mouseDown(with event: NSEvent) {}

}
