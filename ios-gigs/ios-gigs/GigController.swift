//
//  GigController.swift
//  ios-gigs
//
//  Created by Shawn James on 4/7/20.
//  Copyright © 2020 Shawn James. All rights reserved.
//

import Foundation

//This class will be responsible for signing you up, and logging you in for today then additionally creating gigs, and fetching gigs tomorrow.
class GigController {
    
    enum HTTPMethod: String {
        case get = "GET"
        case post = "POST"
    }
    
    enum NetworkError: Error {
        case failedSignUp, failedSignIn, noData, badData
        case notSignedIn, failedFetch, badURL
    }
    
    var bearer: Bearer?
    var gigs = [Gig]()
    
    private let baseURL = URL(string: "https://lambdagigapi.herokuapp.com/api")!
    private lazy var signUpURL = baseURL.appendingPathComponent("users/signup")
    private lazy var loginURL = baseURL.appendingPathComponent("users/login")
    private lazy var getGigsURL = baseURL.appendingPathComponent("gigs/")
    private lazy var gigURL = baseURL.appendingPathComponent("gigs")
    
    private lazy var jsonEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return encoder
    }()
    
    private lazy var jsonDecoder = JSONDecoder()
    
    func signUp(with user: User, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        var request = postRequest(for: signUpURL)
        
        do {
            let jsonData = try jsonEncoder.encode(user)
            print(String(data: jsonData, encoding: .utf8)!)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    print("Sign up failed with error: \(error.localizedDescription)")
                    completion(.failure(.failedSignUp))
                    return
                }
                guard let response = response as? HTTPURLResponse,
                    response.statusCode == 200
                    else {
                        print("Sign up was unsuccessful")
                        return completion(.failure(.failedSignUp))
                }
                completion(.success(true))
            }
            .resume()
        } catch {
            print("Error encoding user: \(error.localizedDescription)")
            completion(.failure(.failedSignUp))
        }
    }
    
    func logIn(with user: User, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        var request = postRequest(for: loginURL)
        
        do {
            let jsonData = try jsonEncoder.encode(user)
            request.httpBody = jsonData
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("Sign in failed with error: \(error.localizedDescription)")
                    completion(.failure(.failedSignIn))
                    return
                }
                
                guard let response = response as? HTTPURLResponse,
                    response.statusCode == 200
                    else {
                        print("Sign in was unsuccessful")
                        return completion(.failure(.failedSignIn))
                }
                guard let data = data else {
                    print("Data was not recieved")
                    completion(.failure(.noData))
                    return
                }
                
                do {
                    self.bearer = try self.jsonDecoder.decode(Bearer.self, from: data)
                    completion(.success(true))
                } catch {
                    print("Error decoding bearer: \(error.localizedDescription)")
                    completion(.failure(.failedSignIn))
                }
            }
            .resume()
        } catch {
            print("Error encoding user: \(error.localizedDescription)")
            completion(.failure(.failedSignIn))
        }
    }
    
    private func postRequest(for url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
    
    func getAllGigs(completion: @escaping (Result<[Gig], NetworkError>) -> Void) {
        guard let bearer = bearer else {
            completion(.failure(.notSignedIn))
            return
        }
        
        let request = getRequest(for: getGigsURL, bearer: bearer)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to get gig names with error: \(error.localizedDescription)")
                completion(.failure(.failedFetch))
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                response.statusCode == 200
                else {
                    print("Gig names recieved bad response")
                    completion(.failure(.failedFetch))
                    return
            }
            
            guard let data = data else {
                return completion(.failure(.badData))
            }
            do {
                self.gigs = try self.jsonDecoder.decode([Gig].self, from: data)
                completion(.success(self.gigs))
            } catch {
                print("Error decoding Gigs: \(error.localizedDescription)")
                completion(.failure(.badData))
            }
        }
        .resume()
    }
    
    func postAGig(for gig: Gig, completion: @escaping (Result<[Gig], NetworkError>) -> Void) {
        guard let bearer = bearer else {
            completion(.failure(.notSignedIn))
            return
        }
        
        let request = getRequest(for: gigURL, bearer: bearer)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Failed to post a gig with error: \(error.localizedDescription)")
                completion(.failure(.failedFetch))
                return
            }
            
            guard let response = response as? HTTPURLResponse,
                response.statusCode == 200
                else {
                    print("Gig recieved bad response")
                    completion(.failure(.failedFetch))
                    return
            }
            
            guard let data = data else {
                return completion(.failure(.badData))
            }
            
            do {
                let newGig = try self.jsonDecoder.decode([Gig].self, from: data)
                completion(.success(newGig))
                // self.gigs.append(newGig)
            } catch {
                print("Error decoding Gig: \(error.localizedDescription)")
                completion(.failure(.badURL))
            }
        }
        .resume()
    }
    
    
    
    private func getRequest(for url: URL, bearer: Bearer) -> URLRequest {
        var request = URLRequest(url: url)
        request.addValue("Bearer \(bearer.token)", forHTTPHeaderField: "Authorization")
        return request
    }
    
}
