//
//  SVGAEntity.swift
//  Pods
//
//  Created by clovelu on 2020/6/24.
//

import Foundation
import QuartzCore
import UIKit
import ZIPFoundation

open class SVGASpriteEntity {
  /// 元件所对应的位图键名, 如果 imageKey 含有 .vector 后缀，该 sprite 为矢量图层 含有 .matte 后缀，该 sprite 为遮罩图层。
  open var imageKey: String = ""
  /// 被遮罩图层的 matteKey 对应的是其遮罩图层的 imageKey.
  open var matteKey: String = ""
  open var frames: [SVGAFrameEntity] = []

  init?(pb: Svga_SpriteEntity) {
    imageKey = pb.imageKey
    matteKey = pb.matteKey

    var tFrame: SVGAFrameEntity?
    frames = pb.frames.compactMap { pbFrame in
      let frame = SVGAFrameEntity(pb: pbFrame)
      if frame?.isKeepShapes == true {
        frame?.shapes = tFrame?.shapes ?? []
      }
      tFrame = frame
      return frame
    }
  }

  public func frame(at index: Int) -> SVGAFrameEntity? {
    guard index >= 0 && index < frames.count else { return nil }
    return frames[index]
  }
}

open class SVGAFrameEntity {
  open var alpha: CGFloat = 0
  open var layout: CGRect = .zero
  open var transform: CGAffineTransform = .identity
  open var shapes: [SVGAShapeEntity] = []
  open var nx: CGFloat = 0
  open var ny: CGFloat = 0
  open var clipPath: String = ""
  open lazy var clipBezierPath: UIBezierPath? = {
    UIBezierPath(svgaPaths: clipPath)
  }()
  open var isKeepShapes: Bool = false  // 与前帧一致

  init?(pb: Svga_FrameEntity) {
    alpha = CGFloat(pb.alpha)
    layout = CGRect(
      x: CGFloat(pb.layout.x),
      y: CGFloat(pb.layout.y),
      width: CGFloat(pb.layout.width),
      height: CGFloat(pb.layout.height)
    )
    transform =
      if pb.hasTransform {
        CGAffineTransform(
          a: CGFloat(pb.transform.a),
          b: CGFloat(pb.transform.b),
          c: CGFloat(pb.transform.c),
          d: CGFloat(pb.transform.d),
          tx: CGFloat(pb.transform.tx),
          ty: CGFloat(pb.transform.ty))
      } else {
        .identity
      }
    clipPath = pb.clipPath
    //clipBezierPath = UIBezierPath(svgaPaths: clipPath)

    shapes = pb.shapes.compactMap({ (pbShape) -> SVGAShapeEntity? in
      return SVGAShapeEntity(pb: pbShape)
    })
    isKeepShapes = (shapes.first?.type == SVGAShapeEntity.ShapeType.keep)

    let llx = transform.a * layout.origin.x + transform.c * layout.origin.y + transform.tx
    let lrx =
      transform.a * (layout.origin.x + layout.size.width) + transform.c * layout.origin.y
      + transform.tx
    let lbx =
      transform.a * layout.origin.x + transform.c * (layout.origin.y + layout.size.height)
      + transform.tx
    let rbx =
      transform.a * (layout.origin.x + layout.size.width) + transform.c
      * (layout.origin.y + layout.size.height) + transform.tx
    let lly = transform.b * layout.origin.x + transform.d * layout.origin.y + transform.ty
    let lry =
      transform.b * (layout.origin.x + layout.size.width) + transform.d * layout.origin.y
      + transform.ty
    let lby =
      transform.b * layout.origin.x + transform.d * (layout.origin.y + layout.size.height)
      + transform.ty
    let rby =
      transform.b * (layout.origin.x + layout.size.width) + transform.d
      * (layout.origin.y + layout.size.height) + transform.ty
    nx = min(min(lbx, rbx), min(llx, lrx))
    ny = min(min(lby, rby), min(lly, lry))
  }
}

open class SVGAShapeEntity {
  public enum ShapeType: Int {
    case shape = 0  // 路径
    case rect = 1  // 矩形
    case ellipse = 2  // 圆形
    case keep = 3  // 与前帧一致
  }

  public struct ShapeArgs {
    public var d: String = ""
    public lazy var bezierPath: UIBezierPath? = {
      UIBezierPath(svgaPaths: d)
    }()

    init(d: String) {
      self.d = d
    }
  }

  public struct RectArgs {
    public var rect: CGRect = .zero
    public var cornerRadius: CGFloat = 0
    public lazy var bezierPath: UIBezierPath? = {
      UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius)
    }()

    init?(pb: Svga_ShapeEntity.RectArgs) {
      rect = CGRect(
        x: CGFloat(pb.x),
        y: CGFloat(pb.y),
        width: CGFloat(pb.width),
        height: CGFloat(pb.height)
      )
      cornerRadius = CGFloat(pb.cornerRadius)
    }
  }

  public struct EllipseArgs {
    public var center: CGPoint = .zero
    public var radiusX: CGFloat = 0
    public var radiusY: CGFloat = 0
    public lazy var bezierPath: UIBezierPath = {
      UIBezierPath(
        ovalIn: CGRect(
          x: center.x - radiusX, y: center.y - radiusY, width: radiusX * 2, height: radiusY * 2))
    }()

    init?(pb: Svga_ShapeEntity.EllipseArgs) {
      center = CGPoint(
        x: CGFloat(pb.x),
        y: CGFloat(pb.y)
      )
      radiusX = CGFloat(pb.radiusX)
      radiusY = CGFloat(pb.radiusY)
    }
  }

  public struct ShapeStyle {
    public var fillColor: UIColor?
    public var strokeColor: UIColor?
    public var strokeWidth: CGFloat = 0
    public var miterLimit: CGFloat = 0
    public var lineCap: CAShapeLayerLineCap = .butt
    public var lineJoin: CAShapeLayerLineJoin = .miter

    public var lineDashPhase: CGFloat = 0
    public var lineDashPattern: [CGFloat]?

    public init() {}

    init?(pb: Svga_ShapeEntity.ShapeStyle) {
      fillColor = UIColor(
        red: CGFloat(pb.fill.r),
        green: CGFloat(pb.fill.g),
        blue: CGFloat(pb.fill.b),
        alpha: CGFloat(pb.fill.a)
      )
      strokeColor = UIColor(
        red: CGFloat(pb.stroke.r),
        green: CGFloat(pb.stroke.g),
        blue: CGFloat(pb.stroke.b),
        alpha: CGFloat(pb.stroke.a)
      )
      strokeWidth = CGFloat(pb.strokeWidth)
      miterLimit = CGFloat(pb.miterLimit)

      let capList: [CAShapeLayerLineCap] = [.butt, .round, .square, .butt, .butt]
      let linJoinList: [CAShapeLayerLineJoin] = [.miter, .round, .bevel, .miter, .miter]

      lineCap = capList[pb.lineCap.rawValue]
      lineJoin = linJoinList[pb.lineJoin.rawValue]
      lineDashPhase = CGFloat(pb.lineDashIii)
      lineDashPattern = [
        CGFloat(max(pb.lineDashI, 1.0)),
        CGFloat(max(pb.lineDashIi, 0.1)),
      ]
    }
  }

  open var type: ShapeType = .shape
  open var shape: ShapeArgs?
  open var rect: RectArgs?
  open var ellipse: EllipseArgs?
  open var styles: ShapeStyle?
  open var transform: CGAffineTransform = .identity
  open lazy var bezierPath: UIBezierPath? = {
    switch type {
    case .shape:
      shape?.bezierPath
    case .rect:
      rect?.bezierPath
    case .ellipse:
      ellipse?.bezierPath
    default:
      nil
    }
  }()

  init?(pb: Svga_ShapeEntity) {
    type = ShapeType(rawValue: pb.type.rawValue) ?? .shape
    switch type {
    case .shape:
      shape = ShapeArgs(d: pb.shape.d)
    case .rect:
      rect = RectArgs(pb: pb.rect)
    case .ellipse:
      ellipse = EllipseArgs(pb: pb.ellipse)
    default:
      break
    }

    styles = ShapeStyle(pb: pb.styles)
    transform =
      if pb.hasTransform {
        CGAffineTransform(
          a: CGFloat(pb.transform.a),
          b: CGFloat(pb.transform.b),
          c: CGFloat(pb.transform.c),
          d: CGFloat(pb.transform.d),
          tx: CGFloat(pb.transform.tx),
          ty: CGFloat(pb.transform.ty)
        )
      } else {
        .identity
      }
  }
}

open class SVGAAudioEntity {
  open var audioKey: String = ""
  open var startFrame: Int = 0
  open var endFrame: Int = 0
  open var startTime: Int = 0
  open var totalTime: Int = 0

  init?(pb: Svga_AudioEntity) {
    audioKey = pb.audioKey
    startFrame = Int(pb.startFrame)
    endFrame = Int(pb.endFrame)
    startTime = Int(pb.startTime)
    totalTime = Int(pb.totalTime)
  }
}

open class SVGAMovieEntity {
  open var version: String = ""
  open var size: CGSize = CGSize.zero
  open var fps: Int = 0
  open var frames: Int = 0  // 动画总帧数

  open var imagesTotalSize: Int = 0
  open var images: [String: UIImage] = [:]  // 图片集
  open var sprites: [SVGASpriteEntity] = []  // 元素列表
  open var audios: [SVGAAudioEntity] = []  // 音频列表

  public convenience init(fileURL: URL) throws {
    var isDir: ObjCBool = false
    FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDir)
    if isDir.boolValue {
      let pbURL = fileURL.appendingPathComponent("movie.binary")
      let pbData = try Data(contentsOf: pbURL)
      let pb = try Svga_MovieEntity.init(serializedData: pbData)
      self.init(pb: pb, inDirURL: fileURL)
    }

    let data = try Data(contentsOf: fileURL)
    try self.init(data: data, fileURL: fileURL)
  }

  /// convenience init
  /// - Parameters:
  ///   - data: svga data
  ///   - fileURL: data store url use for 1.x
  public convenience init(data: Data, fileURL: URL? = nil) throws {
    if data.count < 4 {
      throw NSError(
        domain: "SVGAMovieEntity.init",
        code: NSURLErrorCannotDecodeRawData,
        userInfo: [NSLocalizedDescriptionKey: "data error"]
      )
    }

    let tag = data.prefix(4)
    let tagStr = tag.map { String(format: "%02.2hhx", $0) }.joined()
    if tagStr != "504b0304" {
      let nData = data.zlibInflate()
      let pb = try Svga_MovieEntity.init(serializedData: nData)
      self.init(pb: pb, inDirURL: fileURL)
      return
    }

    /// 1.x
    let storeURL =
      if let fileURL {
        fileURL
      } else {
        URL(fileURLWithPath: NSTemporaryDirectory() + "/\(data.md5String()).svga")
      }

    if !FileManager.default.fileExists(atPath: storeURL.path) {
      try data.write(to: storeURL)
    }

    let tmpUnzipURL =
      if storeURL.path.hasPrefix(NSHomeDirectory()) {
        storeURL.appendingPathExtension("unzip.tmp")
      } else {
        URL(
          fileURLWithPath:
            "\(NSTemporaryDirectory())/\(storeURL.absoluteString.md5String()).svga.unzip.tmp")
      }

    if !FileManager.default.fileExists(atPath: tmpUnzipURL.path) {
      try FileManager.default.unzipItem(at: storeURL, to: tmpUnzipURL)
    }

    let pbURL = tmpUnzipURL.appendingPathComponent("movie.binary")
    let pbData = try Data(contentsOf: pbURL)
    let pb = try Svga_MovieEntity.init(serializedData: pbData)
    self.init(pb: pb, inDirURL: tmpUnzipURL)
  }

  init(pb: Svga_MovieEntity, inDirURL: URL? = nil) {
    version = pb.version
    size = CGSize(width: CGFloat(pb.params.viewBoxWidth), height: CGFloat(pb.params.viewBoxHeight))
    fps = Int(pb.params.fps)
    frames = Int(pb.params.frames)

    let dirExist = inDirURL != nil ? FileManager.default.fileExists(atPath: inDirURL!.path) : false

    images = pb.images.compactMapValues { data in
      if dirExist {
        let fileName = String(data: data, encoding: .utf8) ?? ""
        let fileURL = inDirURL!.appendingPathComponent("\(fileName).png")
        if let imageData = try? Data(contentsOf: fileURL) {
          imagesTotalSize += data.count
          return UIImage(data: imageData, scale: UIScreen.main.scale)
        }
      }

      imagesTotalSize += data.count
      return UIImage(data: data, scale: UIScreen.main.scale)
    }

    sprites = pb.sprites.compactMap(SVGASpriteEntity.init)
    audios = pb.audios.compactMap(SVGAAudioEntity.init)
  }

  public func image(for key: String) -> UIImage? {
    images[key]
  }

  public func sprite(at index: Int) -> SVGASpriteEntity? {
    guard index >= 0 && index < sprites.count else { return nil }
    return sprites[index]
  }

  public func audio(at index: Int) -> SVGAAudioEntity? {
    guard index >= 0 && index < audios.count else { return nil }
    return audios[index]
  }
}

extension UIBezierPath {
  public convenience init?(svgaPaths: String) {
    guard svgaPaths.count > 0 else { return nil }
    self.init()
    self.setSVGAPaths(svgaPaths)
  }

  func setSVGAPaths(_ paths: String) {
    var values = paths.replacingOccurrences(
      of: "([a-zA-Z])", with: "|||$1 ", options: .regularExpression)
    values = values.replacingOccurrences(of: ",", with: " ")
    let segments = values.components(separatedBy: "|||")
    segments.forEach { segment in
      guard segment.count > 0 else { return }
      let firstLetter = String(segment.prefix(1))
      let args = segment.suffix(segment.count - 1).trimmingCharacters(
        in: CharacterSet.whitespacesAndNewlines
      ).components(separatedBy: " ")
      operate(method: firstLetter, args: args)
    }
  }

  func operate(method: String, args: [String]) {
    switch method {
    case "M", "m": operateM(method: method, args: args)
    case "L", "l": operateL(method: method, args: args)
    case "C", "c": operateC(method: method, args: args)
    case "Q", "q": operateQ(method: method, args: args)
    case "H", "h": operateH(method: method, args: args)
    case "V", "v": operateV(method: method, args: args)
    case "Z", "z": operateZ(method: method, args: args)
    default: break
    }
  }

  func operateM(method: String, args: [String]) {
    guard args.count == 2 else { return }
    let relative = method == "m"
    var p = CGPoint(
      x: CGFloat(Float(args[0])!),
      y: CGFloat(Float(args[1])!))
    p = argPoint(p, relative: relative)
    self.move(to: p)
  }

  func operateL(method: String, args: [String]) {
    guard args.count == 2 else { return }
    let relative = method == "l"
    var p = CGPoint(
      x: CGFloat(Float(args[0])!),
      y: CGFloat(Float(args[1])!))
    p = argPoint(p, relative: relative)
    self.addLine(to: p)
  }

  func operateC(method: String, args: [String]) {
    guard args.count == 6 else { return }
    let relative = method == "c"
    var p1 = CGPoint(
      x: CGFloat(Float(args[0])!),
      y: CGFloat(Float(args[1])!))
    var p2 = CGPoint(
      x: CGFloat(Float(args[2])!),
      y: CGFloat(Float(args[3])!))
    var p3 = CGPoint(
      x: CGFloat(Float(args[4])!),
      y: CGFloat(Float(args[5])!))
    p1 = argPoint(p1, relative: relative)
    p2 = argPoint(p2, relative: relative)
    p3 = argPoint(p3, relative: relative)
    self.addCurve(to: p3, controlPoint1: p1, controlPoint2: p2)
  }

  func operateQ(method: String, args: [String]) {
    guard args.count == 4 else { return }
    let relative = method == "q"
    var p1 = CGPoint(
      x: CGFloat(Float(args[0])!),
      y: CGFloat(Float(args[1])!))
    var p2 = CGPoint(
      x: CGFloat(Float(args[2])!),
      y: CGFloat(Float(args[3])!))
    p1 = argPoint(p1, relative: relative)
    p2 = argPoint(p2, relative: relative)

    self.addQuadCurve(to: p2, controlPoint: p1)
  }

  func operateH(method: String, args: [String]) {
    guard args.count == 1 else { return }
    let relative = (method == "h") ? self.currentPoint.x : 0
    let v = CGFloat(Float(args[0]) ?? 0)
    let iv = self.argFloat(v, relative: relative)
    self.addLine(to: CGPoint(x: iv, y: self.currentPoint.y))
  }

  func operateV(method: String, args: [String]) {
    guard args.count == 1 else { return }
    let relative = (method == "v") ? self.currentPoint.y : 0
    let v = CGFloat(Float(args[0]) ?? 0)
    let iv = self.argFloat(v, relative: relative)
    self.addLine(to: CGPoint(x: self.currentPoint.y, y: iv))
  }

  func operateZ(method: String, args: [String]) {
    self.close()
  }

  func argPoint(_ point: CGPoint, relative: Bool) -> CGPoint {
    if relative {
      CGPoint(
        x: point.x + currentPoint.x,
        y: point.y + currentPoint.y
      )
    } else {
      point
    }
  }

  func argFloat(_ value: CGFloat, relative: CGFloat) -> CGFloat {
    value + relative
  }
}
