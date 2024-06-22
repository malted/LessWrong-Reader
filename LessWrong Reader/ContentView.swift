//
//  ContentView.swift
//  LessWrong Reader
//
//  Created by Ben Dixon on 6/22/24.
//


import SwiftUI
import WebKit
import XMLParsing
import MarkdownUI
import SwiftHTMLtoMarkdown

struct ContentView: View {
    @State private var posts = [Post]()

    var body: some View {
        NavigationStack {
            List(posts) { post in
                NavigationLink(destination: PostDetailView(post: post)) {
                    VStack(alignment: .leading) {
                        Text(post.creator ?? "Unknown Author")
                            .font(.headline)
                        Text(post.title)
                    }
                }
            }
            .navigationTitle("LessWrong Curated")
        }
        .task {
            await fetchPosts()
        }
    }

    func fetchPosts() async {
        do {
            posts = try await PostsFetcher.fetchPosts()
        } catch {
            print("Error fetching posts: \(error)")
        }
    }
}

struct PostDetailView: View {
    @State var scrollPos: Float = 0.0
    
    let post: Post
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(post.title)
                    .font(.title)
                    .fontWeight(.bold)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text("By \(post.creator ?? "Unknown Author")")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(post.pubDate)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Divider()
                
                Markdown(post.markdownDescription)
                    .padding(.vertical, 10)
                
                Spacer()
                
                Link("Read full post on LessWrong", destination: URL(string: post.link)!)
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .limitWidth(to: 80)
        }
        .navigationTitle("Post Detail")
    }
}

struct RSS: Codable {
    let channel: Channel
}

struct Channel: Codable {
    let title: String
    let description: String
    let link: String
    let lastBuildDate: String
    let item: [Post]
}

struct Post: Codable, Identifiable {
    let id: String
    let title: String
    let description: String
    let link: String
    let creator: String?
    let pubDate: String
    var markdownDescription: String = ""
    
    enum CodingKeys: String, CodingKey {
        case id = "guid"
        case title
        case description
        case link
        case creator = "dc:creator"
        case pubDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        link = try container.decode(String.self, forKey: .link)
        creator = try container.decodeIfPresent(String.self, forKey: .creator)
        pubDate = try container.decode(String.self, forKey: .pubDate)
    }
}

struct PostsFetcher {
    static func fetchPosts() async throws -> [Post] {
        guard let url = URL(string: "https://www.lesswrong.com/feed.xml?view=curated-rss") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)
        let rss = try XMLDecoder().decode(RSS.self, from: data)
        var posts = rss.channel.item
        
        // Convert HTML to Markdown for each post description
        for i in 0..<posts.count {
            if let markdownDescription = try? await convertHTMLToMarkdown(html: posts[i].description) {
                posts[i].markdownDescription = markdownDescription
            } else {
                posts[i].markdownDescription = "Error converting HTML to Markdown"
            }
        }
        
        return posts
    }
    
    static func convertHTMLToMarkdown(html: String) async throws -> String {
        guard let url = URL(string: "http://localhost:3000") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = html.data(using: .utf8)
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let markdown = String(data: data, encoding: .utf8) else {
            throw URLError(.cannotDecodeContentData)
        }

        return markdown
    }
}

extension String {
    func htmlToString() -> String {
        guard let data = self.data(using: .utf16) else { return self }
        do {
            return try NSAttributedString(data: data, options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf16.rawValue
            ], documentAttributes: nil).string
        } catch {
            print("Error converting HTML to string: \(error)")
            return self
        }
    }
}

struct LimitWidthModifier: ViewModifier {
    let maxCharacters: Int
    
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: CGFloat(maxCharacters) * 8) // Approximate width of 80 characters
            .fixedSize(horizontal: false, vertical: true)
    }
}

extension View {
    func limitWidth(to characters: Int) -> some View {
        self.modifier(LimitWidthModifier(maxCharacters: characters))
    }
}

#Preview {
    ContentView()
}
