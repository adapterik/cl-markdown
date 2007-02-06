(in-package #:cl-markdown)

(defparameter *markup->html*
  (make-container 
   'simple-associative-container
   :test #'equal
   :initial-contents 
   '((header1)    (nil "h1")
     (header2)    (nil "h2")
     (header3)    (nil "h3")
     (header4)    (nil "h4")
     (header5)    (nil "h5")
     (header6)    (nil "h6")
     
     (bullet)     (("ul") "li")
     (code)       (("pre" "code") nil encode-pre)
     (number)     (("ol") "li")
     (quote)      (("blockquote") nil)
     (horizontal-rule) (nil "hr"))))

(defgeneric render-to-html (stuff encoding-method)
  (:documentation ""))

(defmethod render ((document document) (style (eql :html)) stream)
  (declare (ignore stream))
  (render-to-html document nil))

(defun html-marker (chunk)
  (bind ((markup (markup-class-for-html chunk)))
    (first markup)))

;;; ---------------------------------------------------------------------------

(defmethod render-to-html ((chunk chunk) encoding-method)
  (bind (((&optional nil markup new-method) (markup-class-for-html chunk))
         (paragraph? (paragraph? chunk)))
    (encode-html chunk (or new-method encoding-method)
		 markup (when paragraph? "p"))))
  
;;; ---------------------------------------------------------------------------
  
(defmethod encode-html ((stuff chunk) encoding-method &rest codes)
  (declare (dynamic-extent codes))
  (cond ((null codes) 
         (let ((class (member 'code (markup-class stuff))))
           (iterate-elements
            (lines stuff)
            (lambda (line)
              (render-to-html line encoding-method)
              (when class (format *output-stream* "~%"))))))
        ((null (first codes))
         (apply #'encode-html stuff encoding-method (rest codes)))
        (t (format *output-stream* "<~a>" (first codes))
           (apply #'encode-html stuff encoding-method (rest codes))
           (format *output-stream* "</~a>" (first codes))
           (unless (length-1-list-p codes) 
             (terpri *output-stream*)))))

;;; ---------------------------------------------------------------------------

(defmethod encode-html ((stuff list) encoding-method &rest codes)
  (declare (dynamic-extent codes))
  (cond ((null codes) 
         (iterate-elements
          stuff
          (lambda (line)
            ;(spy (type-of line))
            (render-to-html line encoding-method))))
        ((null (first codes))
         (apply #'encode-html stuff encoding-method (rest codes)))
        (t (format *output-stream* "<~A>" (first codes))
           (apply #'encode-html stuff encoding-method (rest codes))
           (format *output-stream* "</~A>" (first codes))
           (unless (length-1-list-p codes) 
             (terpri *output-stream*)))))

;;; ---------------------------------------------------------------------------

(defmethod markup-class-for-html ((chunk chunk))
  (when (markup-class chunk)
    (let ((translation (item-at-1 *markup->html* (markup-class chunk))))
      (unless translation 
        (warn "No translation for '~A'" (markup-class chunk)))
      translation)))

;;; ---------------------------------------------------------------------------

(defmethod render-to-html ((chunk list) encoding-method)
  (render-span-to-html (first chunk) (rest chunk) encoding-method))

;;; ---------------------------------------------------------------------------

(defmethod render-to-html ((line string) encoding-method)
  (format *output-stream* "~A"  
	  (funcall (or encoding-method 'encode-string-for-html) line)))

;;; ---------------------------------------------------------------------------

(defun output-html (string &rest codes)
  (declare (dynamic-extent codes))
  (cond ((null codes) (princ (first string) *output-stream*))
        (t (format *output-stream* "<~A>" (first codes))
           (apply #'output-html string (rest codes))
           (format *output-stream* "</~A>" (first codes)))))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'strong)) body encoding-method)
  (declare (ignore encoding-method))
  (output-html body 'strong))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'mail)) body encoding-method)
  (declare (ignore encoding-method))
  (let ((address (first body)))
    (output-link (format nil "mailto:~A" address) nil address)))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'emphasis)) body encoding-method)
  (declare (ignore encoding-method))
  (output-html body 'em))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'strong-em)) body encoding-method)
  (declare (ignore encoding-method))
  (output-html body 'strong 'em))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html 
    ((code (eql 'escaped-character)) body encoding-method)
  (declare (ignore encoding-method))
  (output-html body))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'code)) body encoding-method)
  (format *output-stream* "<code>")
  (dolist (bit body)
    (render-to-html bit encoding-method))
  (format *output-stream* "</code>"))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'entity)) body encoding-method)
  (declare (ignore encoding-method))
  (output-html body))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html 
    ((code (eql 'reference-link)) body encoding-method)
  (declare (ignore encoding-method))
  (bind (((values text id supplied?)
          (if (length-1-list-p body)
            (values (first body) (first body) nil)
            (values (butlast body 1) (first (last body)) t)))
         (link-info (item-at-1 (link-info *current-document*) id)))
    (cond ((not (null link-info))
           ;; it _was_ a valid ID
           (output-link (url link-info) (title link-info) text))
          (t
           ;;?? hackish
           (format *output-stream* "[~a][~a]" text (if supplied? id ""))))))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html 
    ((code (eql 'inline-link)) body encoding-method)
  (declare (ignore encoding-method))
  (bind (((text &optional (url "") title) body))
    (output-link url title text)))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'link)) body encoding-method)
  (declare (ignore encoding-method))
  (let ((link (first body)))
    (output-link link nil link)))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html 
    ((code (eql 'reference-image)) body encoding-method)
  (declare (ignore encoding-method))
  (bind (((values text id supplied?)
          (if (length-1-list-p body)
            (values (first body) (first body) nil)
            (values (butlast body 1) (first (last body)) t)))
         (link-info (item-at-1 (link-info *current-document*) id)))
    (cond ((not (null link-info))
           ;; it _was_ a valid ID
           (output-image (url link-info) (title link-info) text))
          (t
           ;;?? hackish
           (format *output-stream* "[~a][~a]" text (if supplied? id ""))))))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html 
    ((code (eql 'inline-image)) body encoding-method)
  (declare (ignore encoding-method))
  (bind (((text &optional (url "") title) body))
    (output-image url title text)))

;;; ---------------------------------------------------------------------------

(defun output-link (url title text)
  (cond ((not (null url))
         (format *output-stream* "<a href=\"~A\"~@[ title=\"~A\"~]>"
                 url title)
         (encode-html (ensure-list text) nil)
         (format *output-stream* "</a>"))
        (t
         )))

;;; ---------------------------------------------------------------------------

(defun output-image (url title text)
  (cond ((not (null url))
         (format *output-stream* "<img src=\"~A\"~@[ title=\"~A\"~]~@[ alt=\"~A\"~]></img>"
                 url title text))
        (t
         )))

;;; ---------------------------------------------------------------------------

(defmethod render-span-to-html ((code (eql 'html)) body encoding-method)
  ;; hack!
  (let ((output (first body)))
    (etypecase output
      (string 
       (output-html (list (html-encode:encode-for-pre output))))
      (list
       (render-span-to-html (first output) (rest output) encoding-method)))))

;;; ---------------------------------------------------------------------------

(defmethod render-to-html ((document document) encoding-method) 
  (labels ((do-it (chunks level)
             (loop for rest = chunks then (rest rest) 
                   for chunk = (first rest) then (first rest) 
                   while chunk 
                   for new-level = (level chunk)
                   for markup = (html-marker chunk) 
                   when (= level new-level) do 
		  (render-to-html chunk encoding-method)
                   when (< level new-level) do
                   (dolist (marker markup)
                     (format *output-stream* "<~A>" marker))
                   (multiple-value-bind (block remaining method)
                                        (next-block rest new-level)
                     (declare (ignore method))
                     (do-it (next-block block new-level) new-level)
                     (setf rest remaining))
                   (dolist (marker (reverse markup))
                     (format *output-stream* "</~A>" marker))
                   #+(or)
                   (format *output-stream* "~%"))))
    (when (document-property "html")
      (generate-html-header))
    (do-it (collect-elements (chunks document)) 
           (level document))
    (when (document-property "html")
      (format *output-stream* "~&</body>~&</html>"))))

(defvar *html-meta*
  '((name (author description copyright keywords date))
    (http-equiv (refresh expires))))

(defun generate-html-header ()
  (generate-doctype)
  (format *output-stream* "~&<html>~&<head>")
  (awhen (document-property "title")
    (format *output-stream* "~&<title>~a</title>" it))
  (awhen (document-property "style-sheet")
    (unless (search ".css" it)
      (setf it (concatenate 'string it ".css")))
    (format *output-stream* "~&<link type='text/css' href='~a' rel='stylesheet' />" it))
  (loop for (kind properties) in *html-meta* do
       (loop for property in properties do
	    (awhen (document-property (symbol-name property))
	      (format *output-stream* "~&<meta ~a=\"~a\" content=\"~a\"/>"
		      kind property it))))
  (format *output-stream* "~&</head>~&<body>"))

;;; ---------------------------------------------------------------------------

(defun generate-doctype ()
  (format *output-stream* "~&<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.0 Strict//EN\"
        \"http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd\">"))


;; Copied from HTML-Encode
;;?? this is very consy
;;?? crappy name
(defun encode-string-for-html (string)
  (declare (simple-string string))
  (let ((output (make-array (truncate (length string) 2/3)
                            :element-type 'character
                            :adjustable t
                            :fill-pointer 0)))
    (with-output-to-string (out output)
      (loop for char across string
            do (case char
                 ((#\&) (write-string "&amp;" out))
                 ;((#\<) (write-string "&lt;" out))
                 ;((#\>) (write-string "&gt;" out))
                 (t (write-char char out)))))
    (coerce output 'simple-string)))


;; Copied from HTML-Encode
;;?? this is very consy
;;?? crappy name
(defun encode-pre (string)
  (declare (simple-string string))
  (let ((output (make-array (truncate (length string) 2/3)
                            :element-type 'character
                            :adjustable t
                            :fill-pointer 0)))
    (with-output-to-string (out output)
      (loop for char across string
            do (case char
                 ((#\&) (write-string "&amp;" out))
                 ((#\<) (write-string "&lt;" out))
                 ((#\>) (write-string "&gt;" out))
                 (t (write-char char out)))))
    (coerce output 'simple-string)))
