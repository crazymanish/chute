//
//  GithubNotifier.swift
//  chute
//
//  Created by David House on 11/1/17.
//  Copyright © 2017 David House. All rights reserved.
//

import Foundation

class GithubNotifier {

    func notify(using environment: Environment, including dataCapture: DataCapture, publishedURL: String?) {
    
        if let repository = environment.arguments.githubRepository, let pullRequestNumber = environment.arguments.pullRequestNumber, let token = environment.arguments.githubToken {
            
            let comment = GithubDetailComment(dataCapture: dataCapture, publishedURL: publishedURL)
            if let existingCommentID = existingComment(startingWith: "# Chute Detail", foundIn: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL) {
                
                update(comment: comment.comment, withID: existingCommentID, to: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL)
            } else {
                create(comment: comment.comment, to: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL)
            }
        }
    }

    func notify(using environment: Environment, including difference: DataCaptureDifference, publishedURL: String?) {

        if let repository = environment.arguments.githubRepository, let pullRequestNumber = environment.arguments.pullRequestNumber, let token = environment.arguments.githubToken {
            
            let comment = GithubDetailDifferenceComment(difference: difference, publishedURL: publishedURL)
            if let existingCommentID = existingComment(startingWith: "# Chute Difference", foundIn: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL) {
            
                update(comment: comment.comment, withID: existingCommentID, to: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL)
            } else {
                create(comment: comment.comment, to: repository, for: pullRequestNumber, using: token, apiurl: environment.arguments.githubAPIURL)
            }
        }
    }

    private func existingComment(startingWith: String, foundIn repository: String, for pullRequest: String, using token: String, apiurl: String?) -> String? {
        
        // Create a URL for this request
        let urlString = "https://\(apiurl ?? "api.github.com")/repos/\(repository)/issues/\(pullRequest)/comments"
        guard let postURL = URL(string: urlString) else {
            print("--- Error creating URL for posting to github: \(urlString)")
            return nil
        }
        
        var request = URLRequest(url: postURL)
        request.httpMethod = "GET"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        var foundID: String? = nil
        
        let semaphore = DispatchSemaphore(value: 0)
        let dataTask = URLSession(configuration: URLSessionConfiguration.default).dataTask(with: request) { (data, _, error) in
            
            if let error = error {
                print("--- Error getting comments from github: \(error.localizedDescription)")
            }
            
            if let data = data {
                let dataString = String(data: data, encoding: .utf8)
                print("--- Response: \(dataString ?? "")")

                do {
                    if let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                        
                        for comment in jsonResponse {
                            
                            for (key, value) in comment {
                                if key == "body", let body = value as? String, body.starts(with: startingWith) {
                                    
                                    for (key, value) in comment {
                                        if key == "id", let commentID = value as? Int {
                                            foundID = String(commentID)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        print("--- Unable to parse JSON response")
                    }
                } catch {
                    print("--- Error parsing json response: \(error.localizedDescription)")
                }
            }
            semaphore.signal()
        }
        dataTask.resume()
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(30))
        return foundID
    }
    
    private func create(comment: String, to repository: String, for pullRequest: String, using token: String, apiurl: String?) {

        // Create a URL for this request
        let urlString = "https://\(apiurl ?? "api.github.com")/repos/\(repository)/issues/\(pullRequest)/comments"
        guard let postURL = URL(string: urlString) else {
            print("--- Error creating URL for posting to github: \(urlString)")
            return
        }

        var request = URLRequest(url: postURL)
        request.httpMethod = "POST"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = [
            "body": comment
        ]
        let encoder = JSONEncoder()
        do {
            let rawBody = try encoder.encode(body)
            request.httpBody = rawBody
        } catch {
            print("--- Error encoding body: \(error)")
        }

        let semaphore = DispatchSemaphore(value: 0)
        let dataTask = URLSession(configuration: URLSessionConfiguration.default).dataTask(with: request) { (data, _, error) in

            if let error = error {
                print("--- Error posting comment to github: \(error.localizedDescription)")
            }

            if let data = data {
                let dataString = String(data: data, encoding: .utf8)
                print("--- Response: \(dataString ?? "")")
            }
            semaphore.signal()
        }
        dataTask.resume()
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(30))
    }
    
    private func update(comment: String, withID: String, to repository: String, for pullRequest: String, using token: String, apiurl: String?) {
        
        // Create a URL for this request
        let urlString = "https://\(apiurl ?? "api.github.com")/repos/\(repository)/issues/comments/\(withID)"
        guard let postURL = URL(string: urlString) else {
            print("--- Error creating URL for patching to github: \(urlString)")
            return
        }
        
        var request = URLRequest(url: postURL)
        request.httpMethod = "PATCH"
        request.setValue("token \(token)", forHTTPHeaderField: "Authorization")
        
        let body: [String: String] = [
            "body": comment
        ]
        let encoder = JSONEncoder()
        do {
            let rawBody = try encoder.encode(body)
            request.httpBody = rawBody
        } catch {
            print("--- Error encoding body: \(error)")
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        let dataTask = URLSession(configuration: URLSessionConfiguration.default).dataTask(with: request) { (data, _, error) in
            
            if let error = error {
                print("--- Error patching comment to github: \(error.localizedDescription)")
            }
            
            if let data = data {
                let dataString = String(data: data, encoding: .utf8)
                print("--- Response: \(dataString ?? "")")
            }
            semaphore.signal()
        }
        dataTask.resume()
        _ = semaphore.wait(timeout: DispatchTime.now() + DispatchTimeInterval.seconds(30))
    }
}
