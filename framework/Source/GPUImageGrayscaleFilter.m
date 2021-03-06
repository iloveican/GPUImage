#import "GPUImageGrayscaleFilter.h"

@implementation GPUImageGrayscaleFilter

NSString *const kGPUImageLuminanceFragmentShaderString = SHADER_STRING
(
 precision highp float;
 
 varying vec2 textureCoordinate;
 
 uniform sampler2D inputImageTexture;
 
 const highp vec3 W = vec3(0.2125, 0.7154, 0.0721);
 
 void main()
 {
     lowp vec4 textureColor = texture2D(inputImageTexture, textureCoordinate);
     float luminance = dot(textureColor.rgb, W);
     
     gl_FragColor = vec4(vec3(luminance), textureColor.a);
 }
);

- (void)renderToTextureWithVertices:(const GLfloat *)vertices textureCoordinates:(const GLfloat *)textureCoordinates sourceTexture:(GLuint)sourceTexture;
{
    if (!currentlyReceivingMonochromeInput)
    {
        [super renderToTextureWithVertices:vertices textureCoordinates:textureCoordinates sourceTexture:sourceTexture];
    }
}

- (void)setInputTexture:(GLuint)newInputTexture atIndex:(NSInteger)textureIndex;
{
    [super setInputTexture:newInputTexture atIndex:textureIndex];
    if (currentlyReceivingMonochromeInput)
    {
        [self notifyTargetsAboutNewOutputTexture];
    }
}

- (GLuint)textureForOutput;
{
    if (currentlyReceivingMonochromeInput)
    {
        return filterSourceTexture;
    }
    else
    {
        return outputTexture;
    }
}

- (BOOL)wantsMonochromeInput;
{
    return YES;
}

- (BOOL)providesMonochromeOutput;
{
    return YES;
}

- (void)informTargetsAboutNewFrameAtTime:(CMTime)frameTime;
{
    if (self.frameProcessingCompletionBlock != NULL)
    {
        self.frameProcessingCompletionBlock(self, frameTime);
    }
    
    [self releaseInputTexturesIfNeeded];
    
    for (id<GPUImageInput> currentTarget in targets)
    {
        if (currentTarget != self.targetToIgnoreForUpdates)
        {
            NSInteger indexOfObject = [targets indexOfObject:currentTarget];
            NSInteger textureIndex = [[targetTextureIndices objectAtIndex:indexOfObject] integerValue];
            
            if ([GPUImageOpenGLESContext supportsFastTextureUpload] && preparedToCaptureImage)
            {
                [self setInputTextureForTarget:currentTarget atIndex:textureIndex];
            }

            if (currentlyReceivingMonochromeInput)
            {
                [currentTarget setInputRotation:inputRotation atIndex:textureIndex];
                
                CGSize sizeToRotate = [self outputFrameSize];
                CGSize rotatedSize = sizeToRotate;
                if (GPUImageRotationSwapsWidthAndHeight(inputRotation))
                {
                    rotatedSize.width = sizeToRotate.height;
                    rotatedSize.height = sizeToRotate.width;
                }
                [currentTarget setInputSize:rotatedSize atIndex:textureIndex];
            }
            else
            {
                [currentTarget setInputSize:[self outputFrameSize] atIndex:textureIndex];
            }
            [currentTarget newFrameReadyAtTime:frameTime atIndex:textureIndex];
        }
    }
}

#pragma mark -
#pragma mark Initialization and teardown

- (id)init;
{
    if (!(self = [super initWithFragmentShaderFromString:kGPUImageLuminanceFragmentShaderString]))
    {
		return nil;
    }
    
    return self;
}


@end
