import Foundation
import IOSE2ECoordinatorCore
@preconcurrency import NIOCore
@preconcurrency import NIOHTTP1
@preconcurrency import NIOPosix
@preconcurrency import NIOWebSocket

public final class E2EWebSocketCoordinatorServer {
    public struct Configuration: Sendable {
        public let bindHost: String
        public let port: Int
        public let path: String

        public init(bindHost: String = "127.0.0.1", port: Int = 0, path: String = "/e2e/session") {
            self.bindHost = bindHost
            self.port = port
            self.path = path
        }
    }

    public private(set) var boundPort: Int?

    private let configuration: Configuration
    private let session: E2EWireSession
    private let eventLoopGroup: MultiThreadedEventLoopGroup
    private let openChannels = E2EWebSocketOpenChannels()
    private var channel: Channel?
    private var stopped = false

    public init(
        configuration: Configuration = Configuration(),
        core: E2ESessionEventCore,
        recorder: E2EWebSocketSessionRecording? = nil
    ) {
        self.configuration = configuration
        self.session = E2EWireSession(core: core, recorder: recorder)
        self.eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    }

    deinit {
        try? stop()
    }

    public func start() throws -> Int {
        let bootstrap = ServerBootstrap(group: eventLoopGroup)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { [session, configuration, openChannels] channel in
                openChannels.append(channel)
                channel.closeFuture.whenComplete { _ in
                    openChannels.remove(channel)
                }

                let upgrader = NIOWebSocketServerUpgrader(
                    shouldUpgrade: { channel, _ in
                        channel.eventLoop.makeSucceededFuture(HTTPHeaders())
                    },
                    upgradePipelineHandler: { channel, _ in
                        channel.pipeline.addHandler(E2EWebSocketPeerHandler(
                            session: session,
                            path: configuration.path
                        ))
                    }
                )

                let upgradeConfiguration = NIOHTTPServerUpgradeConfiguration(
                    upgraders: [upgrader],
                    completionHandler: { _ in }
                )

                return channel.pipeline.configureHTTPServerPipeline(withServerUpgrade: upgradeConfiguration)
            }
            .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

        let channel = try bootstrap.bind(
            host: configuration.bindHost,
            port: configuration.port
        ).wait()
        self.channel = channel
        self.boundPort = channel.localAddress?.port

        guard let boundPort else {
            throw E2EWebSocketTransportError.missingBoundPort
        }

        return boundPort
    }

    public func stop() throws {
        guard stopped == false else { return }
        stopped = true

        if let channel {
            channel.close(mode: .all, promise: nil)
            self.channel = nil
        }

        for childChannel in openChannels.removeAll() {
            childChannel.close(mode: .all, promise: nil)
        }

        try eventLoopGroup.syncShutdownGracefully()
    }
}

private final class E2EWebSocketOpenChannels: @unchecked Sendable {
    private let lock = NSLock()
    private var channels: [ObjectIdentifier: Channel] = [:]

    func append(_ channel: Channel) {
        lock.withLock {
            channels[ObjectIdentifier(channel)] = channel
        }
    }

    func remove(_ channel: Channel) {
        _ = lock.withLock {
            channels.removeValue(forKey: ObjectIdentifier(channel))
        }
    }

    func removeAll() -> [Channel] {
        lock.withLock {
            defer { channels.removeAll() }
            return Array(channels.values)
        }
    }
}

public protocol E2EWebSocketSessionRecording: Sendable {
    func recordEventJSON(_ json: String)
    func recordReceiptJSON(_ json: String)
}

public enum E2EWebSocketTransportError: Error, Equatable, Sendable {
    case missingBoundPort
    case invalidTextFrame
    case unsupportedMessageType(String)
    case peerNotConnected(E2EPeerName)
}

final class E2EWebSocketPeerHandler: ChannelInboundHandler, @unchecked Sendable {
    typealias InboundIn = WebSocketFrame
    typealias OutboundOut = WebSocketFrame

    private let session: E2EWireSession
    private let path: String
    private var peerName: E2EPeerName?
    private var connection: E2EWebSocketTextConnection?

    init(session: E2EWireSession, path: String) {
        self.session = session
        self.path = path
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let frame = unwrapInboundIn(data)
        guard frame.opcode == .text else {
            context.close(promise: nil)
            return
        }

        var frameData = frame.unmaskedData
        guard let text = frameData.readString(length: frameData.readableBytes) else {
            context.close(promise: nil)
            return
        }

        do {
            try handle(text, channel: context.channel)
        } catch {
            context.close(promise: nil)
        }
    }

    func channelInactive(context: ChannelHandlerContext) {
        session.disconnect(peerName: peerName)
    }

    private func handle(_ text: String, channel: Channel) throws {
        let connection = self.connection ?? E2EWebSocketTextConnection(channel: channel)
        self.connection = connection
        if let connectedPeer = try session.handleText(text, from: connection) {
            peerName = connectedPeer
        }
    }
}

private final class E2EWebSocketTextConnection: E2EWireTextConnection, @unchecked Sendable {
    private let channel: Channel

    init(channel: Channel) {
        self.channel = channel
    }

    func sendText(_ text: String) {
        var buffer = channel.allocator.buffer(capacity: text.utf8.count)
        buffer.writeString(text)
        let frame = WebSocketFrame(fin: true, opcode: .text, data: buffer)
        channel.writeAndFlush(frame, promise: nil)
    }
}
