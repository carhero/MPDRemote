// MusicDataSource.swift
// Copyright (c) 2017 Nyx0uf
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


import Foundation


final class MusicDataSource
{
	// MARK: - Public properties
	// Singletion instance
	static let shared = MusicDataSource()
	// MPD server
	var server: AudioServer! = nil
	// Selected display type
	private(set) var displayType = DisplayType.albums
	// Albums list
	private(set) var albums = [Album]()
	// Genres list
	private(set) var genres = [Genre]()
	// Artists list
	private(set) var artists = [Artist]()
	// Playlists list
	private(set) var playlists = [Playlist]()

	// MARK: - Private properties
	// MPD Connection
	private var _connection: AudioServerConnection! = nil
	// Serial queue for the connection
	private let _queue: DispatchQueue
	// Timer (1sec)
	private var _timer: DispatchSourceTimer!

	// MARK: - Initializers
	init()
	{
		self._queue = DispatchQueue(label: "fr.whine.mpdremote.queue.datasource", qos: .default, attributes: [], autoreleaseFrequency: .inherit, target:  nil)

		NotificationCenter.default.addObserver(self, selector: #selector(audioServerConfigurationDidChange(_:)), name: .audioServerConfigurationDidChange, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground(_:)), name: .UIApplicationDidEnterBackground, object:nil)
		NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground(_:)), name: .UIApplicationWillEnterForeground, object:nil)
	}

	// MARK: - Public
	@discardableResult func initialize() -> Bool
	{
		// Sanity check 1
		if _connection != nil && _connection.isConnected
		{
			return true
		}

		// Sanity check 2
		guard let server = server else
		{
			MessageView.shared.showWithMessage(message: Message(content: NYXLocalizedString("lbl_message_no_mpd_server"), type: .error))
			return false
		}

		// Connect
		_connection = MPDConnection(server)
		let ret = _connection.connect()
		if ret.succeeded
		{
			_connection.delegate = self
			startTimer(20)
		}
		else
		{
			MessageView.shared.showWithMessage(message: ret.messages.first!)
			_connection = nil
		}
		return ret.succeeded
	}

	func deinitialize()
	{
		stopTimer()
		if _connection != nil
		{
			_connection.delegate = nil
			_connection.disconnect()
			_connection = nil
		}
	}

	@discardableResult func reinitialize() -> Bool
	{
		deinitialize()
		return initialize()
	}

	func selectedList() -> [MusicalEntity]
	{
		switch displayType
		{
			case .albums:
				return albums
			case .genres:
				return genres
			case .artists:
				return artists
			case .playlists:
				return playlists
		}
	}

	func getListForDisplayType(_ displayType: DisplayType, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		self.displayType = displayType

		_queue.async {
			let result = self._connection.getListForDisplayType(displayType)
			if result.succeeded == false
			{

			}
			else
			{
				let set = CharacterSet(charactersIn: ".?!:;/+=-*'\"")
				switch (displayType)
				{
				case .albums:
					self.albums = (result.entity as! [Album]).sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)})
				case .genres:
					self.genres = (result.entity as! [Genre]).sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)})
				case .artists:
					self.artists = (result.entity as! [Artist]).sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)})
				case .playlists:
					self.playlists = (result.entity as! [Playlist]).sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)})
				}

				callback()
			}
		}
	}

	func getAlbumsForGenre(_ genre: Genre, firstOnly: Bool, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getAlbumsForGenre(genre, firstOnly: firstOnly)
			if result.succeeded == false
			{

			}
			else
			{
				genre.albums = result.entity!
				callback()
			}
		}
	}

	func getAlbumsForArtist(_ artist: Artist, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getAlbumsForArtist(artist)
			if result.succeeded == false
			{

			}
			else
			{
				let set = CharacterSet(charactersIn: ".?!:;/+=-*'\"")
				artist.albums = result.entity!.sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)})
				callback()
			}
		}
	}

	func getArtistsForGenre(_ genre: Genre, callback: @escaping ([Artist]) -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getArtistsForGenre(genre)
			if result.succeeded == false
			{

			}
			else
			{
				let set = CharacterSet(charactersIn: ".?!:;/+=-*'\"")
				callback(result.entity!.sorted(by: {$0.name.trimmingCharacters(in: set) < $1.name.trimmingCharacters(in: set)}))
			}
		}
	}

	func getPathForAlbum(_ album: Album, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getPathForAlbum(album)
			if result.succeeded == false
			{

			}
			else
			{
				album.path = result.entity
				callback()
			}
		}
	}

	func getTracksForAlbums(_ albums: [Album], callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			for album in albums
			{
				let result = self._connection.getTracksForAlbum(album)
				album.tracks = result.entity
				callback()
			}
		}
	}

	func getTracksForPlaylist(_ playlist: Playlist, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getTracksForPlaylist(playlist)
			if result.succeeded == false
			{

			}
			else
			{
				playlist.tracks = result.entity
				callback()
			}
		}
	}

	func getMetadatasForAlbum(_ album: Album, callback: @escaping () -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getMetadatasForAlbum(album)
			if result.succeeded == false
			{

			}
			else
			{
				let metadatas = result.entity!
				if let artist = metadatas["artist"] as! String?
				{
					album.artist = artist
				}
				if let year = metadatas["year"] as! String?
				{
					album.year = year
				}
				if let genre = metadatas["genre"] as! String?
				{
					album.genre = genre
				}

				callback()
			}
		}
	}

	func getStats(_ callback: @escaping ([String : String]) -> Void)
	{
		if _connection == nil || _connection.isConnected == false
		{
			return
		}

		_queue.async {
			let result = self._connection.getStats()
			if result.succeeded == false
			{

			}
			else
			{
				callback(result.entity!)
			}
		}
	}

	// MARK: - Private
	private func startTimer(_ interval: Int)
	{
		_timer = DispatchSource.makeTimerSource(flags: DispatchSource.TimerFlags(rawValue: UInt(0)), queue: _queue)
		_timer.schedule(deadline: .now(), repeating: .seconds(interval))
		_timer.setEventHandler {
			self.getPlayerStatus()
		}
		_timer.resume()
	}

	private func stopTimer()
	{
		if _timer != nil
		{
			_timer.cancel()
			_timer = nil
		}
	}

	private func getPlayerStatus()
	{
		_ = _connection.getStatus()
	}

	// MARK: - Notifications
	@objc func audioServerConfigurationDidChange(_ aNotification: Notification)
	{
		if let server = aNotification.object as? AudioServer
		{
			self.server = server
			self.reinitialize()
		}
	}

	@objc func applicationDidEnterBackground(_ aNotification: Notification)
	{
		deinitialize()
	}

	@objc func applicationWillEnterForeground(_ aNotification: Notification)
	{
		reinitialize()
	}
}

extension MusicDataSource : AudioServerConnectionDelegate
{
	func albumMatchingName(_ name: String) -> Album?
	{
		let albums = MusicDataSource.shared.albums
		return albums.filter({$0.name == name}).first
	}
}
